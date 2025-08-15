pipeline {
  agent any
  options { timestamps() } // Show timestamps in build logs

  environment {
    // AWS/ECR config
    AWS_REGION       = 'eu-central-1'
    AWS_ACCOUNT_ID   = '054037117483'
    ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    // EKS config
    EKS_CLUSTER      = 'my-eks-cluster'
    KUBE_NAMESPACE   = 'default'

    // Helm config
    CHART_PATH       = 'helm'
    RELEASE_NAME     = 'my-app'

    // Only build/deploy these services if they change
    SERVICES_WHITELIST = 'adservice cartservice checkoutservice currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice redis-cart shippingservice'
  }

  stages {

    // ---------------------------
    // 1. Checkout repository
    // ---------------------------
    stage('Checkout') {
      steps {
        echo "=== Stage: CHECKOUT ==="
        checkout scm
        sh 'git rev-parse --short HEAD'
      }
    }

    // ---------------------------
    // 2. Detect which services changed
    // ---------------------------
    stage('Figure out changed services') {
      steps {
        echo "=== Stage: DETECT CHANGES ==="
        script {
          // Find base commit for comparison
          def base = sh(returnStdout: true, script: '''
            git fetch --quiet origin || true
            if [ -n "${GIT_PREVIOUS_SUCCESSFUL_COMMIT}" ]; then
              echo "${GIT_PREVIOUS_SUCCESSFUL_COMMIT}"
            else
              git merge-base HEAD origin/main || echo ""
            fi
          ''').trim()

          echo "Base commit for diff: ${base}"

          // List changed top-level service directories
          def changed = sh(returnStdout: true, script: """
            if [ -z "${base}" ]; then
              echo "${SERVICES_WHITELIST}"
            else
              git diff --name-only "${base}" HEAD \
                | awk -F/ '/^src\\//{print \$2}' \
                | sort -u
            fi
          """).trim().split('\n').findAll { it?.trim() }

          // Filter against whitelist
          def allowed = SERVICES_WHITELIST.split(' ')
          def targets = changed.findAll { allowed.contains(it) }

          if (targets.isEmpty()) {
            echo "No services changed."
            env.CHANGED_SERVICES = ''
          } else {
            echo "Changed services detected: ${targets.join(', ')}"
            env.CHANGED_SERVICES = targets.join(' ')
          }
        }
      }
    }

    // ---------------------------
    // 3. AWS ECR login
    // ---------------------------
    stage('AWS / ECR Login') {
      when { expression { return env.CHANGED_SERVICES?.trim() } }
      steps {
        echo "=== Stage: AWS/ECR LOGIN ==="
        sh '''
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$ECR_REGISTRY"
        '''
      }
    }

    // ---------------------------
    // 4. Build & Push only changed images
    // ---------------------------
    stage('Build & Push changed images') {
      when { expression { return env.CHANGED_SERVICES?.trim() } }
      steps {
        echo "=== Stage: BUILD & PUSH IMAGES ==="
        script {
          // Use short Git commit hash as image tag
          env.IMAGE_TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          echo "Using IMAGE_TAG=${IMAGE_TAG}"

          // Ensure Docker Buildx is available
          sh '''#!/usr/bin/env bash
          set -euo pipefail
          docker version || true
          docker buildx version || true
          docker buildx create --name jxbuilder --use >/dev/null 2>&1 || docker buildx use jxbuilder
          docker buildx inspect --bootstrap >/dev/null 2>&1 || true
          '''

          // Build & push each changed service
          for (svc in env.CHANGED_SERVICES.split(' ')) {
            echo "--- Building & pushing: ${svc} ---"
            sh """#!/usr/bin/env bash
            set -euo pipefail

            docker buildx build \\
              --progress=plain \\
              --platform linux/amd64 \\
              -f "src/${svc}/Dockerfile" \\
              -t "${ECR_REGISTRY}/${svc}:${IMAGE_TAG}" \\
              --cache-from=type=registry,ref="${ECR_REGISTRY}/${svc}:buildcache" \\
              --cache-to=type=registry,ref="${ECR_REGISTRY}/${svc}:buildcache,mode=max" \\
              --provenance=false --sbom=false \\
              --push \\
              "src/${svc}"

              # Free up disk space after each build
              docker buildx prune -af --verbose || true
              """
          }
        }
      }
    }

    // ---------------------------
    // 5. Helm upgrade only changed services
    // ---------------------------
    stage('Helm upgrade (only changed services)') {
      when { expression { return env.CHANGED_SERVICES?.trim() } }
      steps {
        echo "=== Stage: HELM UPGRADE ==="
        sh '''
          # Update kubeconfig for EKS cluster
          aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"

          SET_OPTS=""
          for svc in ${CHANGED_SERVICES}; do
            echo "Updating Helm value for: $svc"
            SET_OPTS="$SET_OPTS --set-string ${svc}.tag=${IMAGE_TAG}"
          done

          # Upgrade or install Helm release
          helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --reuse-values \
            --set-string images.repository="$ECR_REGISTRY" \
            $SET_OPTS \
            --namespace "$KUBE_NAMESPACE" \
            --create-namespace \
            --wait --timeout 10m

          # Show pods after deployment
          kubectl -n "$KUBE_NAMESPACE" get pods
        '''
      }
    }
  }

  // ---------------------------
  // Post-build cleanup
  // ---------------------------
  post {
    always {
      echo "=== Post build: Logout from ECR ==="
      sh 'docker logout "$ECR_REGISTRY" || true'
    }
  }
}
