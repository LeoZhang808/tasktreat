# TaskTreat — Step 5: Public Ingress, DNS, HTTPS

> **Note (post-Step 7):** the public Ingress was originally created in the
> dev overlay (this doc as written). It has since been moved to the prod
> overlay (`k8s/overlays/prod/`) so prod owns `app.tasktreat.dev`; dev now
> strips the Ingress and is reached only via `kubectl port-forward`. The
> mechanism described below is unchanged — substitute `prod` for `dev`
> wherever a path or namespace appears.

This step exposes the cluster behind a single AWS Application Load Balancer
provisioned by the AWS Load Balancer Controller, fronted by a custom domain
(`tasktreat.dev`) registered through the GitHub Student Developer Pack at
Name.com, with TLS provided by an ACM certificate.

```
Browser
  │  HTTPS
  ▼
app.tasktreat.dev   (Route 53 alias A record)
  │
  ▼
AWS Application Load Balancer  (ACM cert: app.tasktreat.dev)
  │
  ▼
Kubernetes Ingress  (tasktreat-dev/tasktreat-ingress, ingressClassName: alb)
  │
  ├── /              → frontend          :80
  ├── /api/tasks     → task-service      :4001
  ├── /api/wishlist  → wishlist-service  :4002
  └── /api/rewards   → reward-service    :4003
```

The backend microservices stay `ClusterIP` only — no per-service public
load balancers — so the ALB is the one and only ingress point.

---

## What was added in this step

### Terraform (`infra/terraform/`)

| Path                                                         | Purpose                                                                                              |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `modules/route53/`                                           | Public hosted zone for `var.domain_name` (e.g. `tasktreat.dev`).                                     |
| `modules/acm/`                                               | DNS-validated ACM certificate for `app.tasktreat.dev`. Validation records auto-created in Route 53.  |
| `modules/aws-load-balancer-controller-irsa/`                 | IAM role + customer-managed policy + EKS-OIDC trust for the controller's `ServiceAccount`.           |
| `modules/aws-load-balancer-controller-irsa/iam_policy.json`  | Pinned copy of the upstream policy (v2.11.0).                                                        |
| `environments/dev/main.tf`                                   | Wires the three new modules in.                                                                      |
| `environments/dev/variables.tf` / `terraform.tfvars`         | Adds `domain_name = "tasktreat.dev"` and `app_subdomain = "app"`.                                    |
| `environments/dev/outputs.tf`                                | Exposes hosted zone ID, NS list, ACM ARN, app FQDN, controller role ARN.                             |

### Kubernetes (`k8s/`)

| Path                                              | Purpose                                                                                 |
| ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `base/ingress.yaml`                               | Path-based Ingress with AWS LBC annotations. Catch-all `/` is last.                     |
| `base/kustomization.yaml`                         | Lists `ingress.yaml` so it is rendered with the rest of the base.                       |
| `overlays/dev/ingress-patch.yaml.template`        | Committed template; placeholders for `__APP_FQDN__` and `__ACM_CERTIFICATE_ARN__`.      |
| `overlays/dev/kustomization.yaml`                 | Strategic-merge patch points at `ingress-patch.yaml` (rendered file, gitignored).       |

### Scripts (`scripts/`)

| Script                              | What it does                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------- |
| `install-aws-lb-controller.sh`      | Creates/annotates the kube-system SA, then `helm upgrade --install` of AWS LBC.       |
| `render-ingress-patch.sh`           | Reads `terraform output` and writes the env-specific Ingress patch.                   |
| `deploy-ingress.sh`                 | Renders the patch, `kubectl apply -k`s the overlay, waits for the ALB to come up.     |
| `upsert-app-dns.sh`                 | UPSERTs an A-alias record in Route 53 pointing the app FQDN at the ALB.               |
| `verify-step5.sh`                   | Walks every Step 5 acceptance check and prints PASS/FAIL.                             |

---

## End-to-end runbook

Pre-reqs: AWS CLI logged in, Terraform initialised in `environments/dev`,
`kubectl` / `helm` / `jq` on `PATH`, and the Step 4 deployment is healthy
in the `tasktreat-dev` namespace.

### 1. Apply Terraform

```bash
cd infra/terraform/environments/dev
terraform init
terraform apply
```

Apply prints, among others:

```
route53_name_servers = [
  "ns-XXX.awsdns-XX.com",
  "ns-XXX.awsdns-XX.net",
  "ns-XXX.awsdns-XX.org",
  "ns-XXX.awsdns-XX.co.uk",
]
```

### 2. Delegate Name.com → Route 53 (one-time, manual)

Log in to [Name.com](https://www.name.com/account/domain) → `tasktreat.dev`
→ **Manage Nameservers** → replace the four Name.com defaults with the four
addresses above. Save.

> Until this step lands, the ACM DNS-validation records Terraform created
> are *invisible* to ACM, so the cert sticks in `PENDING_VALIDATION` and
> the apply blocks at `aws_acm_certificate_validation`. Re-run
> `terraform apply` after the nameservers propagate (usually a few
> minutes; up to 30 min worst case). Use:
>
> ```bash
> dig +short NS tasktreat.dev
> ```
>
> to confirm Route 53 is now authoritative.

### 3. Install the AWS Load Balancer Controller

```bash
./scripts/install-aws-lb-controller.sh
```

The script reads the IAM role ARN, cluster name, region, and VPC ID from
`terraform output`, creates the IRSA-annotated SA, then `helm upgrade
--install`s the controller chart pinned to a known-good version.

Verify:

```bash
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system logs deployment/aws-load-balancer-controller | tail
```

### 4. Deploy the Ingress

```bash
./scripts/deploy-ingress.sh
```

This:

1. Renders `k8s/overlays/dev/ingress-patch.yaml` from the template using
   the live ACM cert ARN and the `app.tasktreat.dev` FQDN.
2. `kubectl apply -k k8s/overlays/dev`.
3. Waits up to 3 minutes for the Ingress to acquire an ALB hostname.

### 5. Point the app FQDN at the ALB

```bash
./scripts/upsert-app-dns.sh
```

This is automated end-to-end: it reads the Ingress' ALB hostname, looks
up that ALB's `CanonicalHostedZoneId` via the ELBv2 API (the right way —
do not hard-code it), and UPSERTs an A-alias record in the Route 53 zone
Terraform created.

### 6. Verify

```bash
./scripts/verify-step5.sh
```

Expected: 8 PASS lines covering the controller, the ALB, the cert, DNS,
HTTPS, and per-path API routing.

Then open <https://app.tasktreat.dev> in a browser. You should see the
TaskTreat UI with a closed-lock icon next to the URL.

---

## Why this design

| Decision                                          | Why                                                                                                                                         |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **One ALB, path-based routing**                   | Cheaper, fewer public attack surfaces, and matches the spec.                                                                                |
| **DNS in Route 53, registrar at Name.com**        | Lets Terraform manage records and gives ACM DNS validation. Name.com is treated as a dumb registrar.                                        |
| **Subdomain `app.` instead of the apex**          | A normal CNAME/alias works for any subdomain. Apex aliases are awkward unless DNS provider supports ANAME-style records.                    |
| **DNS validation, not email validation**          | Fully automatable, idempotent, and Terraform-friendly. Email validation requires a human to click a link.                                   |
| **IRSA, not node IAM**                            | Least-privilege: only the controller pod gets ALB permissions, not every pod on the node.                                                   |
| **Helm for the controller, Terraform for IRSA**   | The controller is a Kubernetes workload and Helm is the official install path. Its IAM is infrastructure and belongs in Terraform.          |
| **Ingress base + Kustomize overlay patch**        | Same base manifest works in qa/uat/prod — only the host and cert ARN change per environment, exactly what overlays are designed for.        |
| **Controller install + DNS UPSERT as scripts**    | They consume `terraform output`, which Terraform itself can't easily do without `terraform_remote_state` plumbing. Scripts keep it simple.  |

---

## What is intentionally NOT done in Step 5

- ExternalDNS (auto-creating Route 53 records from Ingress annotations) —
  one more component to maintain; the `upsert-app-dns.sh` one-shot is
  enough for now and the IAM trust pattern would mirror this step.
- Terraform-managed alias record for the ALB — would need a `data
  "aws_lb"` lookup post-Ingress; comes later when CD is wired up.
- Wildcard cert — only `app.tasktreat.dev` is needed today.
- Per-environment overlays for qa/uat/prod — Step 6 territory.

---

## Acceptance checklist

| #  | Acceptance criterion                                              | Where it is verified                                          |
| -- | ----------------------------------------------------------------- | ------------------------------------------------------------- |
|  1 | Domain registered through Name.com                                | Manual                                                         |
|  2 | DNS delegated to Route 53                                         | `dig +short NS tasktreat.dev` returns 4 `awsdns` servers      |
|  3 | ACM certificate exists in us-west-2                               | `terraform output acm_certificate_arn` non-empty              |
|  4 | ACM certificate status is ISSUED                                  | `verify-step5.sh` step 4                                      |
|  5 | AWS Load Balancer Controller is installed and Running             | `verify-step5.sh` step 1                                      |
|  6 | Kubernetes Ingress exists                                         | `verify-step5.sh` step 2                                      |
|  7 | Ingress creates an internet-facing ALB                            | `verify-step5.sh` step 3                                      |
|  8 | `app.tasktreat.dev` resolves to the ALB                           | `verify-step5.sh` step 5                                      |
|  9 | https://app.tasktreat.dev loads the frontend                      | `verify-step5.sh` step 6                                      |
| 10 | Browser shows a valid HTTPS lock icon                             | `verify-step5.sh` step 8 + visual                             |
| 11 | `/api/tasks` routes to `task-service`                             | `verify-step5.sh` step 7                                      |
| 12 | `/api/wishlist` routes to `wishlist-service`                      | `verify-step5.sh` step 7                                      |
| 13 | `/api/rewards` routes to `reward-service`                         | `verify-step5.sh` step 7                                      |
| 14 | User can create tasks through the public HTTPS frontend           | Manual: open the SPA, add a task, mark it done                |
| 15 | User can add wishlist items through the public HTTPS frontend     | Manual                                                         |
| 16 | User can generate weekly reward through the public HTTPS frontend | Manual: click "Generate weekly treat" with ≥1 done task + ≥1 wishlist item |
