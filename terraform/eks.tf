# ============================================================
# Terraform - AWS EKS Cluster Configuration
# ============================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  # WHY: Public endpoint for kubectl access from Jenkins/developers
  # In production, restrict to VPN CIDR ranges
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restrict this!
  cluster_endpoint_private_access      = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # WHY: Enable EKS managed add-ons for automatic updates
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # WHY: Managed node groups let AWS handle node lifecycle,
  # patching, and replacement automatically.
  eks_managed_node_groups = {
    # General workload nodes
    general = {
      name           = "devsecops-general"
      instance_types = [var.eks_node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # WHY: Spread nodes across AZs for HA
      subnet_ids = module.vpc.private_subnets

      labels = {
        role = "general"
      }

      # WHY: Encrypt EBS volumes for data at rest
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      update_config = {
        # WHY: Rolling update strategy - keep 30% capacity during update
        max_unavailable_percentage = 33
      }

      tags = {
        Name = "${var.project_name}-node"
      }
    }
  }

  # WHY: Cluster-level logging helps with debugging and compliance
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = var.eks_cluster_name
  }
}

# ── IRSA for EBS CSI Driver ───────────────────────────────────
# WHY: EBS CSI driver needs IAM permissions to create PersistentVolumes
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.project_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# ── IRSA for App ──────────────────────────────────────────────
# WHY: App pod gets AWS permissions via IRSA, not hardcoded keys
module "app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-app-role"

  role_policy_arns = {
    ecr_readonly = aws_iam_policy.ecr_readonly.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["devsecops:devsecops-app-sa"]
    }
  }
}

resource "aws_iam_policy" "ecr_readonly" {
  name = "${var.project_name}-ecr-readonly"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:GetAuthorizationToken"]
      Resource = "*"
    }]
  })
}
