# Incident runbook: deliberate break-and-fix drill

## Scenario

An operator disables **BlockPublicAcls** on the Evidence Vault S3 bucket in the AWS console (configuration drift). This simulates the classic ConMon failure mode: manual console change bypasses change control and weakens AC-3 without updating your evidence pack.

## Preconditions

- Lab deployed: `terraform apply` in `terraform/aws/`
- Baseline verification: `python scripts/verify_controls.py` shows **6/6 PASS**
- CloudTrail is logging to the same evidence vault

## Step 1: Detection

Run automated control verification:

```bash
python scripts/verify_controls.py \
  --bucket "<evidence_vault_bucket>" \
  --trail "earthling-dr-management-audit" \
  --budget "earthling-dr-zero-spend-guardrail" \
  --out evidence/control_verification.json
```

**Expected after drift:** `AC-3` row **FAIL** (one or more public access block flags not `True`). Exit code **1**.

Correlate in CloudTrail (example):

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPublicAccessBlock \
  --max-results 5
```

Capture the event in your evidence folder. This satisfies AU-2 / AU-9 narrative: **who changed what, when**.

## Step 2: Containment

1. Notify the interview panel (or ticket system in production): AC-3 degraded on evidence vault.
2. Do **not** grant broad console admin; use the `dr_operator` role pattern for scoped read first.
3. Optional: SCP or bucket policy would block the change in production; the lab intentionally allows drift for the drill.

## Step 3: Remediation (Governance-as-Code)

```bash
cd terraform/aws
terraform plan
```

**Expected:** plan shows `aws_s3_bucket_public_access_block.evidence_vault` in-place update to restore all four flags to `true`.

```bash
terraform apply
```

## Step 4: Validation

Re-run verification:

```bash
python scripts/verify_controls.py \
  --bucket "<evidence_vault_bucket>" \
  --trail "earthling-dr-management-audit" \
  --budget "earthling-dr-zero-spend-guardrail" \
  --out evidence/control_verification_after_remediation.json
```

**Expected:** **6/6 PASS**, exit code **0**.

## Step 5: Blameless RCA (template)

| Field | Entry |
|-------|--------|
| **Incident ID** | DRILL-AC3-001 |
| **Detection time** | |
| **Detection method** | `verify_controls.py` AC-3 check; CloudTrail `PutBucketPublicAccessBlock` |
| **Impact** | Public ACL block disabled on evidence bucket; AC-3 not met until restored |
| **Root cause** | Manual console change without change ticket or Terraform |
| **Remediation** | `terraform apply` restored `aws_s3_bucket_public_access_block` |
| **Validation** | 6/6 PASS on second verification run |
| **Corrective actions** | SCP deny insecure public access changes; require Terraform plan in CI on merge; daily scheduled `verify_controls.py` |

## Prevention (production extensions)

1. **Service Control Policy:** Deny `s3:PutBucketPublicAccessBlock` except break-glass roles.
2. **CI drift detection:** `terraform plan -detailed-exitcode` on a schedule; fail pipeline on drift.
3. **Immutable evidence:** S3 Object Lock in COMPLIANCE mode for assessment windows.
4. **Alerting:** EventBridge rule on `PutBucketPublicAccessBlock` to SNS or ticketing.

## IR-4 mapping

This drill demonstrates **incident handling**: detect (automated), contain (communicate + scope), eradicate (IaC restore), recover (re-verify), and post-incident review (RCA table above).