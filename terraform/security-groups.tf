# ============================================================
# Security Groups — DevSecOps CI Server
# POLICY: Least privilege. All ingress restricted to
# admin_cidr_blocks (set in terraform.tfvars).
# NEVER set admin_cidr_blocks = ["0.0.0.0/0"] in production.
# Jenkins agents use internal VPC CIDR only (10.0.0.0/16).
# All egress is open so the server can pull packages/images.
# ============================================================
resource "aws_security_group" "ci_server_sg" {
  name        = "${var.project_name}-ci-server-sg"
  description = "Security group for CI server (Jenkins, SonarQube, Nexus)"
  vpc_id      = module.vpc.vpc_id

  # WHY: Only open the ports needed for each tool
  # Jenkins Web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "Jenkins Web UI"
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "SonarQube Web UI"
  }

  # Nexus
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "Nexus Repository"
  }

  # Jenkins JNLP Agent port
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Jenkins agents (internal VPC only)"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "SSH access"
  }

  # All outbound traffic (for apt, docker pull, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-ci-sg"
  }
}
