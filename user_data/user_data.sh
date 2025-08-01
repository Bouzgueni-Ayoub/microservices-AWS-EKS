#!/bin/bash
set -e

echo ">>> Updating system..."
apt-get update -y
apt-get upgrade -y
apt-get install -y unzip openjdk-11-jdk curl gnupg

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

echo ">>> Installing Java..."
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

echo ">>> Starting Jenkins service..."
systemctl enable jenkins
systemctl start jenkins

echo ">>> Jenkins setup complete. Listening on port 8080."
