output "aws_account_id" {
  description = "AWS account ID where the lab is deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "evidence_vault_bucket_name" {
  description = "S3 evidence and recovery vault bucket name."
  value       = aws_s3_bucket.evidence_vault.id
}

output "cloudtrail_arn" {
  description = "ARN of the management audit CloudTrail."
  value       = aws_cloudtrail.management_audit.arn
}

output "cloudtrail_name" {
  description = "Name of the management audit CloudTrail (for verify_controls.py)."
  value       = aws_cloudtrail.management_audit.name
}

output "dr_operator_role_arn" {
  description = "ARN of the least-privilege DR operator IAM role."
  value       = aws_iam_role.dr_operator.arn
}

output "compliance_auditor_role_arn" {
  description = "ARN of the read-only compliance auditor IAM role."
  value       = aws_iam_role.compliance_auditor.arn
}

output "budget_name" {
  description = "Name of the $1.00 FinOps guardrail budget."
  value       = aws_budgets_budget.zero_spend_guardrail.name
}

output "verify_controls_example" {
  description = "Example command to run automated control verification."
  value       = "python scripts/verify_controls.py --bucket ${aws_s3_bucket.evidence_vault.id} --trail ${aws_cloudtrail.management_audit.name} --budget ${aws_budgets_budget.zero_spend_guardrail.name} --out evidence/control_verification.json"
}