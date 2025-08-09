resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = "arn:aws:iam::054037117483:role/JenkinsEKSDeployerRole"
  type          = "STANDARD"
  user_name     = "jenkins:{{SessionName}}"
}

resource "aws_eks_access_policy_association" "jenkins_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = aws_eks_access_entry.jenkins.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
