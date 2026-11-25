# Live Execution, Break-and-Fix, and Teardown Evidence

**Date (UTC):** 2026-11-25  
**Region:** `us-east-1`  
**Identity:** Least-privilege IAM user `arn:aws:iam::<REDACTED-ACCOUNT-ID>:user/sky-lab-admin` (no root access keys used)  
**Spend:** `$0.00` (Free Tier / strict `$1.00` monthly budget guardrail)

---

## 1. Terraform Validation (AWS + Azure)

Both stacks passed `terraform init -backend=false` and `terraform validate` cleanly on `Terraform v1.17.2`:

- `terraform/aws` (`hashicorp/aws v5.100.0`, `hashicorp/random v3.9.1`): `Success! The configuration is valid.`
- `terraform/azure` (`hashicorp/azurerm v4.81.0`, `hashicorp/random v3.9.1`): `Success! The configuration is valid.`

---

## 2. Live `terraform apply` & Real-World SCP Finding

Running `terraform apply` in the brand-new AWS Free Plan account provisioned:

- `aws_iam_role.dr_operator` (`earthling-dr-dr-operator`, tagged `NIST_Control = "AC-6"`)
- `aws_iam_role.compliance_auditor` (`earthling-dr-compliance-auditor`, tagged `NIST_Control = "AC-6"`)
- `aws_budgets_budget.zero_spend_guardrail` (`earthling-dr-zero-spend-guardrail`, `$1.00 USD` monthly limit, 50% actual / 100% forecasted alerts)
- `random_id.bucket_suffix` (`ea357d27`)

### Observed Governance-as-Code Finding (SCP Explicit Deny)
`aws_s3_bucket.evidence_vault` returned HTTP `403 AccessDenied`:

```text
User: arn:aws:iam::<REDACTED-ACCOUNT-ID>:user/sky-lab-admin is not authorized to perform:
s3:CreateBucket on resource: "arn:aws:s3:::earthling-dr-evidence-ea357d27"
with an explicit deny in a service control policy:
arn:aws:organizations::<AWS-MANAGED-ORG>:policy/<ORG-ID>/service_control_policy/<SCP-ID>
```

**Root Cause & Security Takeaway:** Even though the IAM user held `AmazonS3FullAccess` (an identity-based `Allow`), AWS's managed Free Plan Organization Service Control Policy enforced an **explicit `Deny`** on `s3:CreateBucket` while the new account remained in Free Plan sandbox status. In AWS IAM policy evaluation logic, an Organization SCP explicit deny always overrides identity-based allows, demonstrating how organizational guardrails enforce boundaries regardless of local IAM permissions.

---

## 3. Live `AC-6` Least-Privilege Break-and-Fix Drill

### Baseline (Compliant)
```text
aws iam list-attached-role-policies --role-name earthling-dr-dr-operator
-> { "AttachedPolicies": [] }

aws budgets describe-budgets --account-id <REDACTED-ACCOUNT-ID>
-> [{ "Name": "earthling-dr-zero-spend-guardrail", "Limit": { "Amount": "1.0", "Unit": "USD" } }]
```

### Deliberate Drift Introduced (Over-Privileged Policy Attached)
```text
aws iam attach-role-policy --role-name earthling-dr-dr-operator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam list-attached-role-policies --role-name earthling-dr-dr-operator
-> { "AttachedPolicies": [{ "PolicyName": "AdministratorAccess", "PolicyArn": "arn:aws:iam::aws:policy/AdministratorAccess" }] }
```
**Result:** Control `AC-6` (`Least Privilege`) **FAILED** (excess `AdministratorAccess` detected on `earthling-dr-dr-operator`).

### Remediation & Re-Verification
```text
aws iam detach-role-policy --role-name earthling-dr-dr-operator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam list-attached-role-policies --role-name earthling-dr-dr-operator
-> { "AttachedPolicies": [] }
```
**Result:** Control `AC-6` **PASSED** (zero excess managed policies attached).

---

## 4. Clean Teardown & Zero-Resource Proof (`$0.00` Left Running)

```text
terraform destroy -auto-approve -no-color
...
Plan: 0 to add, 0 to change, 4 to destroy.
random_id.bucket_suffix: Destruction complete after 0s
aws_iam_role.dr_operator: Destruction complete after 0s
aws_iam_role.compliance_auditor: Destruction complete after 0s
aws_budgets_budget.zero_spend_guardrail: Destruction complete after 0s

Destroy complete! Resources: 4 destroyed.
```

### Post-Destroy Verification
```text
aws iam list-roles --query "Roles[?starts_with(RoleName,'earthling')].RoleName"
-> []

aws budgets describe-budgets --account-id <REDACTED-ACCOUNT-ID> --query "Budgets[].BudgetName"
-> null
```

All lab resources were cleanly destroyed with zero residual billable infrastructure.
