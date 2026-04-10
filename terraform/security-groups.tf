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
    cidr_blocks = ["0.0.0.0/0"]   # 🔒 Restrict to your office/VPN IP in production
    description = "Jenkins Web UI"
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SonarQube Web UI"
  }

  # Nexus
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    cidr_blocks = ["0.0.0.0/0"]   # 🔒 Restrict to your IP in production!
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
