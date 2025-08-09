output "eks_cluster_sg" {
  value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}
output "node_role_arn"{
  value=aws_eks_node_group.eks_node_group.node_role_arn
}