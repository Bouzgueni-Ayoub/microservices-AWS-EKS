#!/bin/bash
set -e

echo ">>> Updating system..."
apt-get update -y
apt-get upgrade -y

echo ">>> Installing base packages..."
apt-get install -y unzip curl gnupg ca-certificates lsb-release

apt-get install -y openjdk-11-jdk

echo ">>> Installing AWS CLI v2..."
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo ">>> Installing Java 17..."
apt-get install -y openjdk-17-jdk

echo ">>> Adding Jenkins repo key and source..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

echo ">>> Installing Jenkins..."
apt-get update -y
apt-get install -y jenkins

echo ">>> Installing Docker (for builds & pushes)..."
apt-get install -y docker.io
systemctl enable --now docker


# Allow the 'jenkins' user to run Docker without sudo
usermod -aG docker jenkins

echo ">>> Installing kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl version --client=true || true

echo ">>> Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version || true

echo ">>> Starting Jenkins service..."
systemctl enable jenkins
systemctl restart jenkins   # restart so new docker group membership is picked up

echo ">>> Jenkins setup complete. Listening on port 8080."
echo ">>> Docker, kubectl, and Helm installed."
