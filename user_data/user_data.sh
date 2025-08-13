#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo ">>> Base update & essentials"
apt-get update -y
apt-get install -y unzip curl gnupg ca-certificates lsb-release jq

echo ">>> Java 17 (only) and set default"
apt-get install -y openjdk-17-jdk
update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || true
java -version || true

echo ">>> AWS CLI v2"
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo ">>> Add Jenkins apt repo"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list >/dev/null

echo ">>> Add Docker official apt repo"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null

echo ">>> Install pinned Jenkins LTS + Docker CE"
apt-get update -y

# Pick a stable LTS available in your repo; adjust if needed:
JENKINS_VERSION="2.462.3"
# If that version isn't available, install the default then hold.
if apt-cache policy jenkins | grep -q "${JENKINS_VERSION}"; then
  apt-get install -y jenkins=${JENKINS_VERSION}
else
  apt-get install -y jenkins
fi
apt-mark hold jenkins

# Remove Ubuntu docker.io if present (idempotent), then install Docker CE stack
apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo ">>> Enable Docker & allow jenkins to use it"
systemctl enable --now docker
usermod -aG docker jenkins

# Enable BuildKit by default
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'JSON'
{
  "features": { "buildkit": true }
}
JSON
systemctl restart docker

echo ">>> Configure Jenkins: skip setup wizard, create admin user"
install -d -o jenkins -g jenkins /var/lib/jenkins/init.groovy.d
cat >/var/lib/jenkins/init.groovy.d/basic-security.groovy <<'GROOVY'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()
def realm = new HudsonPrivateSecurityRealm(false)
if (realm.getAllUsers().find{ it.id == "admin" } == null) {
  realm.createAccount("admin", "changeme123")
}
instance.setSecurityRealm(realm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
GROOVY
chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# Mark install as complete to bypass Setup Wizard
su -s /bin/bash -c '
  mkdir -p /var/lib/jenkins
  echo 2.0 > /var/lib/jenkins/jenkins.install.UpgradeWizard.state
  echo 2.0 > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
' jenkins

echo ">>> Start Jenkins"
systemctl enable jenkins
systemctl restart jenkins

echo ">>> Wait for Jenkins to be up..."
for i in {1..60}; do
  if curl -sf http://localhost:8080/login > /dev/null; then
    echo "Jenkins is up."
    break
  fi
  sleep 2
done

echo ">>> Jenkins CLI download"
curl -fsSL -o /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar

# Admin creds for CLI
JENKINS_URL="http://localhost:8080"
JENKINS_AUTH="admin:changeme123"

echo ">>> Install required plugins (let Jenkins resolve compatible versions)"
# Keep this list lean; Jenkins will pull compatible deps for the pinned core
PLUGINS=(
  "workflow-aggregator"
  "pipeline-stage-view"
  "pipeline-graph-view"
  "pipeline-groovy-lib"
  "pipeline-model-definition"
  "pipeline-multibranch"
  "git"
  "git-client"
  "github"
  "github-branch-source"
  "junit"
  "matrix-project"
  "ws-cleanup"
  "echarts-api"
  "bootstrap5-api"
)

for p in "${PLUGINS[@]}"; do
  java -jar /tmp/jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_AUTH" install-plugin "$p" || true
done

echo ">>> Safe restart Jenkins to load plugins"
java -jar /tmp/jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_AUTH" safe-restart || true

echo ">>> kubectl"
KUBECTL_VERSION="$(curl -sL https://dl.k8s.io/release/stable.txt)"
curl -sL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo ">>> Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ">>> Pre-create buildx builder for jenkins"
sudo -u jenkins -H bash -lc '
  docker buildx version
  docker buildx create --name jenkinsbuilder --driver docker-container --use || true
  docker buildx inspect --bootstrap || true
'

echo ">>> DONE: Jenkins (pinned) + Plugins installed, Docker+Buildx, kubectl, Helm."
