data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  common_tags = {
    Project     = "earthling-cloud-dr-lab"
    Owner       = "Sky Coleman"
    ManagedBy   = "Terraform"
    Environment = "lab"
  }
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# CP-9, SC-28, AC-3: Evidence and recovery vault
resource "aws_s3_bucket" "evidence_vault" {
  bucket = "${var.lab_name_prefix}-evidence-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    NIST_Control = "CP-9,SC-28,AC-3"
    Name         = "earthling-evidence-vault"
  })
}

resource "aws_s3_bucket_versioning" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "evidence_vault" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.evidence_vault.arn, "${aws_s3_bucket.evidence_vault.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.evidence_vault.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${local.partition}:cloudtrail:${var.aws_region}:${local.account_id}:trail/${var.lab_name_prefix}-management-audit"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.evidence_vault.arn}/cloudtrail/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${local.partition}:cloudtrail:${var.aws_region}:${local.account_id}:trail/${var.lab_name_prefix}-management-audit"]
    }
  }
}

resource "aws_s3_bucket_policy" "evidence_vault" {
  bucket = aws_s3_bucket.evidence_vault.id
  policy = data.aws_iam_policy_document.evidence_vault.json

  depends_on = [aws_s3_bucket_public_access_block.evidence_vault]
}

# AU-2, AU-9: Management events audit trail (first trail in region is free)
resource "aws_cloudtrail" "management_audit" {
  name                          = "${var.lab_name_prefix}-management-audit"
  s3_bucket_name                = aws_s3_bucket.evidence_vault.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(local.common_tags, {
    NIST_Control = "AU-2,AU-9"
    Name         = "earthling-management-audit"
  })

  depends_on = [aws_s3_bucket_policy.evidence_vault]
}

# AC-6: Least-privilege DR operator role
resource "aws_iam_role" "dr_operator" {
  name = "${var.lab_name_prefix}-dr-operator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${local.account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalAccount" = local.account_id
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    NIST_Control = "AC-6"
    Name         = "earthling-dr-operator"
  })
}

resource "aws_iam_role_policy" "dr_operator" {
  name = "dr-verification-scope"
  role = aws_iam_role.dr_operator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadEvidenceVault"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = [
          aws_s3_bucket.evidence_vault.arn,
          "${aws_s3_bucket.evidence_vault.arn}/*"
        ]
      },
      {
        Sid    = "ReadCloudTrailStatus"
        Effect = "Allow"
        Action = [
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# AC-6: Read-only compliance auditor role
resource "aws_iam_role" "compliance_auditor" {
  name = "${var.lab_name_prefix}-compliance-auditor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${local.account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalAccount" = local.account_id
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    NIST_Control = "AC-6"
    Name         = "earthling-compliance-auditor"
  })
}

resource "aws_iam_role_policy" "compliance_auditor" {
  name = "read-only-evidence"
  role = aws_iam_role.compliance_auditor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuditReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = [
          aws_s3_bucket.evidence_vault.arn,
          "${aws_s3_bucket.evidence_vault.arn}/*"
        ]
      },
      {
        Sid    = "CloudTrailReadOnly"
        Effect = "Allow"
        Action = [
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "BudgetReadOnly"
        Effect = "Allow"
        Action = [
          "budgets:ViewBudget"
        ]
        Resource = "*"
      }
    ]
  })
}

# FinOps: $1.00 monthly spend guardrail
resource "aws_budgets_budget" "zero_spend_guardrail" {
  name         = "${var.lab_name_prefix}-zero-spend-guardrail"
  budget_type  = "COST"
  limit_amount = "1.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}