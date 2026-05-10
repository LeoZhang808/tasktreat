# Presentation notes — Hook + app, then Terraform

Rough budget: 2–3 minutes on the app, 3–4 minutes on IaC (adjust to your total slot).

---

## Part A — Hook + app

### What to have on screen

1. **README.md** (repo root) — scroll so lines **3–15** are visible (hook + ASCII diagram).
2. **package.json** — lines **1–11** (workspaces = proof of 3 backends + frontend).
3. Optional third beat: **services/reward-service/README.md** lines **1–8** (reward calls others; separate microservice). Line **32** if you want one sentence on reward picking logic without opening code.

### What to say (you can read loosely)

- TaskTreat is a task board plus wishlist; finishing tasks feeds a weekly random treat from that wishlist. One sentence on why that matters for the assignment: it is not a single CRUD service — traffic fans out across services.
- Frontend is Vite/React; traffic goes to three HTTP APIs: `/api/tasks`, `/api/wishlist`, `/api/rewards`.
- Postgres is one database; each backend owns its own tables via Prisma (say that if asked how “microservices” share data — shared DB, bounded contexts, no cross-table writes from the wrong service).
- **`reward-service` is the orchestrator**: it talks to task and wishlist over HTTP (point at reward-service README line 3). That satisfies “three microservices” with real boundaries.
- In production the DB is **RDS** and the workloads run on **EKS** — you will tie that to Terraform next.

### Optional (10 seconds)

- Browser tab: your real **HTTPS** app URL (assignment cares about custom DNS + TLS). Only if it does not waste time.

---

## Part B — IaC (Terraform)

### Mental model for the grader

Say once: **everything AWS-side for this project is declared in Terraform**, not created by clicking around the console. Day 1 create and Day 2 changes are both `plan` / `apply`.

### What to show (order matters)

**1) Composition root — single file**

File: `infra/terraform/environments/dev/main.tf`

Scroll in chunks and name each chunk:

| Lines | What to point at | Say |
| ----- | ---------------- | --- |
| **9–28** | `locals` — `app_fqdn`, `grafana_fqdn`, `common_tags` including `ManagedBy = terraform` | Hostnames are derived from variables; every resource gets the same tags so nothing looks mysterious in the console. |
| **35–47** | `module "vpc"` | VPC and subnets for EKS and RDS. |
| **53–58** | `module "iam"` | IAM roles the cluster and nodes use. |
| **64–77** | `module "ecr"` + `repository_names` | Four repos: frontend + three services — matches the monorepo. |
| **83–109** | `module "eks"` including **`ami_release_version = var.eks_ami_release_version`** | Cluster + managed node group; bumping AMI is your Day 2 node patch story (detail in variables next). |
| **115–152** | `module "github_actions_oidc"` + `aws_eks_access_entry` + `aws_eks_access_policy_association` | CI assumes a role via OIDC; GitHub Actions deploys without long-lived kube secrets; scope is namespace-limited. |
| **172–215** | `kubernetes_role` + `kubernetes_role_binding` for argoproj | Terraform applies Kubernetes RBAC too — needed so the deploy role can manage Argo Rollouts in prod (short version: bootstrap permissions the pipeline cannot give itself). |
| **225–248** | `module "route53"` + `module "acm"` | DNS zone + ACM cert for the app hostname (HTTPS). |
| **260–268** | `module "alb_controller_irsa"` | IRSA so the AWS Load Balancer Controller can create ALBs from Ingress objects. |
| **274–301** | `module "rds"` + **`allowed_security_groups` → EKS cluster SG** | RDS in private subnets; only worker nodes reach it — assignment asks for RDS specifically. |

If you run long, skip reading comments aloud; keep **vpc → iam → ecr → eks → rds → dns/acm**.

**2) Remote state**

File: `infra/terraform/environments/dev/backend.tf` — lines **16–23**

Say: state is in **S3**, **encrypted**, **DynamoDB locking** so two applies cannot corrupt state. You do not need to read the bucket name aloud on video if you prefer privacy.

**3) Kubernetes provider**

File: `infra/terraform/environments/dev/providers.tf` — lines **33–41**

Say: Terraform talks to the live cluster with **`aws eks get-token`** so credentials are short-lived — same pattern operators use with kubectl.

**4) Day 2 AMI knob**

File: `infra/terraform/environments/dev/variables.tf` — lines **115–119** (`eks_ami_release_version`)

Say: OS/security patching for workers is **change this variable + apply**; EKS rolls the managed node group.

**5) Optional extra file (only if you mention Grafana TLS in Terraform)**

File: `infra/terraform/environments/dev/monitoring.tf` — **`module "acm_grafana"`** around lines **33–41**

Say: separate ACM cert for Grafana subdomain so observability TLS is still codified, not manual DNS clicks.

**6) Module inventory (5 seconds)**

Open folder `infra/terraform/modules/` and list names: `vpc`, `iam`, `ecr`, `eks`, `rds`, `route53`, `acm`, `aws-load-balancer-controller-irsa`, `github-actions-oidc`. Say modules stay reusable if you ever split qa/uat/prod AWS accounts.

**7) Deeper runbooks**

Point at **`infra/terraform/README.md`** on disk: “bootstrap, tfvars, outputs, and step-by-step apply live here — I am showing `main.tf` because it is the grading checklist in one scroll.”

---

## Lines drift warning

If you edit these files, line numbers move. Re-check before you record.
