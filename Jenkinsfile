pipeline {
  agent any
  options { timestamps() }

  environment {
    AWS_REGION       = 'eu-central-1'
    AWS_ACCOUNT_ID   = '054037117483'
    ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    EKS_CLUSTER      = 'my-eks-cluster'
    KUBE_NAMESPACE   = 'default'

    CHART_PATH       = 'helm'
    RELEASE_NAME     = 'my-app'

    SERVICES_WHITELIST = 'adservice cartservice checkoutservice currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice redis-cart shippingservice'
  }

  stages {
    stage('Checkout') {
      steps {
        echo "=== Stage: CHECKOUT ==="
        checkout scm
        sh 'git rev-parse --short HEAD'
      }
    }

    stage('Figure out changed services') {
      steps {
        echo "=== Stage: DETECT CHANGES ==="
        script {
          def base = sh(returnStdout: true, script: '''
            git fetch --quiet origin || true
            if [ -n "${GIT_PREVIOUS_SUCCESSFUL_COMMIT}" ]; then
              echo "${GIT_PREVIOUS_SUCCESSFUL_COMMIT}"
            else
              git merge-base HEAD origin/main || echo ""
            fi
          ''').trim()

          echo "Base commit for diff: ${base}"

          def changed = sh(returnStdout: true, script: """
            if [ -z "${base}" ]; then
              echo "${SERVICES_WHITELIST}"
            else
              git diff --name-only "${base}" HEAD \
                | awk -F/ '/^src\\//{print \$2}' \
                | sort -u
            fi
          """).trim().split('\n').findAll { it?.trim() }

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

    stage('Build & Push changed images') {
  when { expression { return env.CHANGED_SERVICES?.trim() } }
  steps {
    echo "=== Stage: BUILD & PUSH IMAGES ==="
    script {
      env.IMAGE_TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
      echo "Using IMAGE_TAG=${IMAGE_TAG}"
      for (svc in env.CHANGED_SERVICES.split(' ')) {
        echo "--- Building & pushing: ${svc} ---"
        sh """
          set -euxo pipefail
          DOCKERFILE="src/${svc}/Dockerfile"
          CONTEXT="src/${svc}"
          IMAGE="${ECR_REGISTRY}/${svc}:${IMAGE_TAG}"

          docker version || true
          docker buildx version || echo "buildx not installed (ok)"

          # Force classic builder for this command only
          DOCKER_BUILDKIT=0 DOCKER_CLI_EXPERIMENTAL= \\
            docker build -f "\$DOCKERFILE" -t "\$IMAGE" "\$CONTEXT"
          docker push "\$IMAGE"
        """
      }
    }
  }
}


    stage('Helm upgrade (only changed services)') {
      when { expression { return env.CHANGED_SERVICES?.trim() } }
      steps {
        echo "=== Stage: HELM UPGRADE ==="
        sh '''
          aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"

          SET_OPTS=""
          for svc in ${CHANGED_SERVICES}; do
            echo "Updating Helm value for: $svc"
            SET_OPTS="$SET_OPTS --set-string ${svc}.tag=${IMAGE_TAG}"
          done

          helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --reuse-values \
            --set-string images.repository="$ECR_REGISTRY" \
            $SET_OPTS \
            --namespace "$KUBE_NAMESPACE" \
            --create-namespace \
            --wait --timeout 10m

          echo "Pods after upgrade:"
          kubectl -n "$KUBE_NAMESPACE" get pods
        '''
      }
    }
  }

  post {
    always {
      echo "=== Post build: Logout from ECR ==="
      sh 'docker logout "$ECR_REGISTRY" || true'
    }
  }
}
