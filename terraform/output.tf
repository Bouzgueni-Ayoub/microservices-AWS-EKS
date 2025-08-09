output "eks_cluster_sg" {
  value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}
