#!/bin/bash
set -e

echo ">>> Updating system..."
apt-get update -y
apt-get upgrade -y

echo ">>> Installing base packages..."
apt-get install -y unzip curl gnupg ca-certificates lsb-release apt-transport-https

echo ">>> Installing Java 11 & 17 (for Jenkins/tooling)..."
apt-get install -y openjdk-11-jdk openjdk-17-jdk

echo ">>> Installing AWS CLI v2..."
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo ">>> Adding Jenkins repo key and source..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

echo ">>> Installing Jenkins..."
apt-get update -y
apt-get install -y jenkins

########################################################################
# Docker CE + BuildKit (daemon + client) and buildx
########################################################################
echo ">>> Installing Docker CE from official repo (includes buildx plugin)..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release; echo "$VERSION_CODENAME")
echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") ${CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo ">>> Enabling BuildKit on the Docker daemon..."
# Backup existing daemon.json if present
if [ -f /etc/docker/daemon.json ]; then
  cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%s)
fi
cat >/etc/docker/daemon.json <<'JSON'
{
  "features": { "buildkit": true }
}
JSON

echo ">>> Enabling BuildKit for all shells and tools (client-side)..."
# These make `docker build` use BuildKit by default and make `docker compose build` use the Docker CLI builder
grep -q 'DOCKER_BUILDKIT' /etc/environment || echo 'DOCKER_BUILDKIT=1' >> /etc/environment
grep -q 'COMPOSE_DOCKER_CLI_BUILD' /etc/environment || echo 'COMPOSE_DOCKER_CLI_BUILD=1' >> /etc/environment

echo ">>> Ensuring Jenkins service gets BuildKit env..."
mkdir -p /etc/systemd/system/jenkins.service.d
cat >/etc/systemd/system/jenkins.service.d/env.conf <<'CONF'
[Service]
Environment=DOCKER_BUILDKIT=1
Environment=COMPOSE_DOCKER_CLI_BUILD=1
CONF

echo ">>> Adding 'jenkins' user to 'docker' group..."
usermod -aG docker jenkins

echo ">>> Enabling and starting Docker..."
systemctl enable docker
systemctl daemon-reload
systemctl restart docker

echo ">>> Initializing docker buildx and setting a default builder..."
# Create and use a persistent builder; ignore if it already exists
su -s /bin/bash -c "docker buildx create --name jxbuilder --use || docker buildx use jxbuilder" jenkins
# Warm up buildx (optional)
su -s /bin/bash -c "docker buildx inspect --bootstrap || true" jenkins

########################################################################
# kubectl & Helm
########################################################################
echo ">>> Installing kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl version --client=true || true

echo ">>> Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version || true

echo ">>> Restarting Jenkins so new env vars & docker group apply..."
systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

########################################################################
# Verification (non-fatal)
########################################################################
echo ">>> Verifying Docker + BuildKit..."
docker info --format '{{json .ClientInfo}}' | grep -i Buildx || true
docker buildx version || true
docker info 2>/dev/null | grep -i -E 'server|buildkit' || true

echo ">>> Setup complete."
echo "    - Jenkins running on port 8080"
echo "    - Docker with BuildKit enabled (daemon + client)"
echo "    - docker buildx configured (builder: jxbuilder)"
echo "    - kubectl and Helm installed"
