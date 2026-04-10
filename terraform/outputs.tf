output "ci_server_public_ip" {
  description = "Public IP of the CI server (Jenkins/SonarQube/Nexus)"
  value       = aws_eip.ci_server_eip.public_ip
}

output "ci_server_instance_id" {
  description = "EC2 Instance ID of CI server"
  value       = aws_instance.ci_server.id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate" {
  description = "Base64 encoded certificate for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.app_repos : k => v.repository_url }
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "app_role_arn" {
  description = "IRSA role ARN for the application"
  value       = module.app_irsa.iam_role_arn
}

output "kubectl_config_command" {
  description = "Command to update kubeconfig for kubectl access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
