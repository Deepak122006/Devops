variable "aws_region" {
  description = "AWS region to deploy infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (production, staging)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "devsecops"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devsecops-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes (for autoscaling)"
  type        = number
  default     = 10
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 3
}

variable "ubuntu_ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS (update per region)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # us-east-1 Ubuntu 22.04
}

variable "ci_instance_type" {
  description = "EC2 instance type for the CI server running Jenkins, SonarQube, and Nexus"
  type        = string
  default     = "t3.large"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH, CI web tools, and the public EKS API endpoint. MUST be set to your real IP(s) - never 0.0.0.0/0 in production."
  type        = list(string)
  # No default — must be set explicitly in terraform.tfvars
  # Example: admin_cidr_blocks = ["YOUR_PUBLIC_IP/32"]
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "ecr_repos" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = ["devsecops-app"]
}
