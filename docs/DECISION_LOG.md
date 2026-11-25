# Architectural decision log

## ADR-001: Terraform over console

**Decision:** All lab infrastructure is declared in Terraform; console is only for the deliberate drift drill.

**Why:** FedRAMP and CMMC continuous monitoring require **repeatable evidence**. Console changes are unruly. Terraform state plus plan/apply gives auditors a clear before/after for CM-6 configuration management.

**Tradeoff:** Slightly slower first deploy vs. instant console clicks. **Gain:** Drift is detectable and reversible in one apply.

---

## ADR-002: Strict $0 scope (no NAT, EC2, RDS, EKS, Config recorder, unattached EIPs)

**Decision:** Lab uses only S3, CloudTrail (first free trail), IAM, and AWS Budgets.

**Why:** Interview candidates should not burn Sky's account or distract the panel with billing surprises. AWS Config charges per configuration item; NAT gateways charge hourly. Those are production ConMon tools, not Shark Tank demo requirements.

**Tradeoff:** No live Config rules in the lab. **Gain:** Story stays honest: "here is the control pattern; Config and GuardDuty layer on in prod."

---

## ADR-003: S3 + CloudTrail + IAM + Budget as the ConMon core

**Decision:** Map AC-3, AC-6, AU-2, AU-9, CP-9, SC-28, and FinOps to those four services.

**Why:** Earthling's audience lives in **Governance-as-Code** and **24x7 evidence**. Those services produce artifacts assessors already expect: encrypted versioned storage, immutable audit trails, least-privilege roles, and spend guardrails.

**Tradeoff:** Does not demonstrate every SSP control. **Gain:** Tight narrative from control ID to Terraform resource to `verify_controls.py` check.

---

## ADR-004: AWS-first deploy, Azure Terraform mirror

**Decision:** Run AWS live in the interview; keep equivalent Azure in `terraform/azure/`.

**Why:** Jeff's engineers span hybrid environments. Showing parallel modules proves multi-cloud ConMon literacy without doubling live spend.

**Tradeoff:** Azure stack is not validated in the same live demo window unless Sky enables a subscription. **Gain:** Mapping doc plus Azure code answers "what about Azure?" immediately.

---

## ADR-005: Production additions (out of lab scope)

**What I would add next:**

| Layer | Production extension |
|-------|----------------------|
| Organization | SCPs denying public S3 and unapproved regions |
| Detection | GuardDuty, Security Hub, EventBridge to ticketing |
| Evidence integrity | S3 Object Lock, cross-region replication for CP-9 |
| IAM | OIDC federation, no long-lived keys, permission boundaries |
| Verification | Scheduled `verify_controls.py` in CI with signed JSON artifacts |
| DR workload | AWS DRS / Azure ASR for actual RTO/RPO tests beyond vault semantics |

**Tradeoff:** Cost and operational complexity. **Gain:** Full MSSP-grade continuous monitoring aligned with Earthling's GovRAMP automation story.