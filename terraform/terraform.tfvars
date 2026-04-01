# ─────────────────────────────────────────────────────────────────────────────
# terraform/terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

# ── General ──────────────────────────────────────────────────────────────────
aws_region   = "us-east-1"      
environment  = "dev"
owner        = "deepa"
project_name = "devsecops"

# ── Networking ───────────────────────────────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# ⚠️  SECURITY: Restrict to YOUR IP only 
allowed_ssh_cidr    = "49.206.14.242/32"
allowed_access_cidr = "49.206.14.242/32"

# ── EC2 Instance Types ────────────────────────────────────────────────────────
jenkins_instance_type   = "t3.medium"
sonarqube_instance_type = "t3.medium"
nexus_instance_type     = "t3.small"

# ── SSH Key Pair ──────────────────────────────────────────────────────────────
key_pair_name = "devsecops-key"

# ── EKS Cluster ───────────────────────────────────────────────────────────────
eks_cluster_name       = "devsecops-eks"
eks_cluster_version    = "1.29"
eks_node_instance_type = "t3.medium"
eks_desired_nodes      = 2
eks_min_nodes          = 1
eks_max_nodes          = 3

# ── ECR ───────────────────────────────────────────────────────────────────────
ecr_repo_name             = "devsecops-app"
ecr_image_retention_count = 10

# ── Terraform State ───────────────────────────────────────────────────────────
terraform_state_bucket = "deepa-devsecops-tfstate-2026"
