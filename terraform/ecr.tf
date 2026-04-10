# ============================================================
# Terraform - ECR Repositories
# ============================================================

resource "aws_ecr_repository" "app_repos" {
  for_each = toset(var.ecr_repos)

  name                 = each.value
  image_tag_mutability = "MUTABLE"   # Allow :latest tag to be overwritten

  # WHY: Scan images on push - first line of automated security defense
  image_scanning_configuration {
    scan_on_push = true
  }

  # WHY: Encrypt images at rest in ECR
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = each.value
  }
}

# ── Lifecycle Policy ──────────────────────────────────────────
# WHY: Auto-delete old untagged images to control ECR storage costs
resource "aws_ecr_lifecycle_policy" "app_lifecycle" {
  for_each   = aws_ecr_repository.app_repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPrefixList  = ["v", "build-"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ── ECR Repository Policy ─────────────────────────────────────
# WHY: Allow EKS node roles to pull images from ECR
resource "aws_ecr_repository_policy" "eks_pull" {
  for_each   = aws_ecr_repository.app_repos
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSPull"
        Effect = "Allow"
        Principal = {
          AWS = module.eks.cluster_iam_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
