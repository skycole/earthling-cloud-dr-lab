# AWS to Azure architectural mapping

This lab implements the same continuous monitoring story on AWS (live) and Azure (Terraform mirror). Use this table when Jeff's team asks how controls translate across clouds for FedRAMP, GovRAMP, or CMMC ConMon.

| Capability | AWS (this lab) | Azure (Terraform mirror) |
|------------|----------------|---------------------------|
| **Identity (AC-6)** | IAM roles: `dr_operator`, `compliance_auditor`; assume-role scoped to account root with `aws:PrincipalAccount` | Entra ID principals + custom RBAC role definitions scoped to resource group |
| **Access enforcement (AC-3)** | S3 Block Public Access (4 flags) + bucket policy deny insecure transport | `allow_nested_items_to_be_public = false`, private blob container, HTTPS-only |
| **Encryption (SC-28)** | S3 default SSE-S3 (`AES256`) | Storage account encryption at rest (Microsoft-managed keys; TLS 1.2 minimum) |
| **Backup / recovery evidence (CP-9)** | S3 versioning on evidence vault | Blob versioning enabled on storage account |
| **Audit logging (AU-2, AU-9)** | CloudTrail management trail, log file validation, logs in evidence vault | Activity logs via diagnostic settings to Log Analytics workspace |
| **Storage & DR pattern** | Versioned S3 vault + (production) AWS Elastic Disaster Recovery | Immutable blob versioning + (production) Azure Site Recovery |
| **Detection** | (Production) GuardDuty + Security Hub | (Production) Microsoft Defender for Cloud + Sentinel |
| **Policy-as-Code** | Organization SCPs, OPA, Checkov, Terraform drift checks | Azure Policy, Terraform plan in CI |
| **FinOps guardrail** | AWS Budgets: $1.00 monthly, 50% actual / 100% forecast alerts | `azurerm_consumption_budget_resource_group` with matching thresholds |
| **Verification** | `scripts/verify_controls.py` against live AWS API via CLI | Extend script pattern with `az` CLI checks (same six control families) |

## Design note

AWS is the **live** interview stack because CloudTrail's first management trail per region and this S3-only footprint stay inside a strict $0 lab envelope. Azure Terraform proves you can express the **same control IDs and evidence story** without rewriting your ConMon narrative for hybrid or multi-cloud assessors.