#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo ">>> Base update & essentials"
apt-get update -y
apt-get upgrade -y
apt-get install -y unzip curl gnupg ca-certificates lsb-release

echo ">>> Java 11 & 17"
apt-get install -y openjdk-11-jdk openjdk-17-jdk
# (Optional) make Java 17 default:
# update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || true

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

echo ">>> Install Jenkins + Docker CE (with buildx & compose)"
apt-get update -y
# Remove Ubuntu's docker.io if preinstalled by an image (idempotent)
apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true
apt-get install -y \
  jenkins \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

echo ">>> Enable Docker & allow jenkins to use it"
systemctl enable --now docker
usermod -aG docker jenkins

# Enable BuildKit by default (recommended)
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'JSON'
{
  "features": { "buildkit": true }
}
JSON
systemctl restart docker

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

echo ">>> Start/Restart Jenkins (pick up docker group)"
systemctl enable jenkins
systemctl restart jenkins

echo ">>> All set: Jenkins on 8080; Docker+Buildx, kubectl, Helm installed."
