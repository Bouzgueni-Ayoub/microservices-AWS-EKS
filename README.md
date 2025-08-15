AWS EKS Microservices CI/CD with Jenkins, Terraform, and Helm

This project automates the deployment of a microservices-based application on Amazon EKS using Terraform for infrastructure provisioning, Jenkins for CI/CD automation, Amazon ECR for container image storage, and Helm for Kubernetes deployments.
It is designed so that only changed services are rebuilt and redeployed, minimizing cost and build times.

PREREQUISITES
1. AWS Account with Access Keys – must be configured locally.
2. Create an S3 bucket in AWS for the Terraform backend.
3. Create an EC2 key pair named "key_pair" for SSH access.
4. Create one ECR repository for each microservice. The repository names must match the folder names in the src directory.
5. Configure the AWS CLI locally using: aws configure

DEPLOYMENT STEPS
Step 1: Provision Infrastructure with Terraform
- Go to the terraform directory: cd terraform
- Initialize Terraform: terraform init
- Apply configuration: terraform apply

This will create:
- A VPC with public and private subnets
- An EKS cluster and node group
- An EC2 instance running Jenkins

Step 2: Access Jenkins
- Open Jenkins in your browser: http://<jenkins-server-ip>:8080
- SSH into the Jenkins server: ssh -i key_pair.pem ec2-user@<jenkins-server-ip>
- Get the Jenkins admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword

Step 3: Configure Jenkins Job
- Create a new Jenkins job using your GitHub repository URL.
- Add a webhook in your GitHub repository:
  Payload URL: http://<jenkins-server-ip>:8080/github-webhook/
  Content type: application/json
  Enable push/pull events.

Step 4: CI/CD Workflow
Once set up:
- Any change in a src/<service> directory will:
  1. Trigger Jenkins via webhook
  2. Build a new Docker image for that service
  3. Push the image to Amazon ECR
  4. Deploy or upgrade the Kubernetes pod with Helm
- If no app exists, Helm will deploy all services except the recently changed ones with their default images.

SERVICES
Each service in src/ has:
- Its own Dockerfile
- Its own ECR repository
- Independent deployment via Helm

TOOLS & TECHNOLOGIES
- AWS EKS for Kubernetes hosting
- Amazon ECR as the container registry
- Terraform for infrastructure provisioning
- Jenkins for CI/CD automation
- Helm for Kubernetes deployments

PIPELINE FLOW
1. Code commit to GitHub
2. GitHub webhook triggers Jenkins
3. Jenkins builds & pushes Docker images to ECR
4. Helm deploys changes to EKS

NOTES
- Only services in SERVICES_WHITELIST inside the Jenkinsfile are built/deployed.
- Worker nodes run in private subnets for security.
