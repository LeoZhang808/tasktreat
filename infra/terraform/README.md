# TaskTreat — Terraform Infrastructure (Step 3)

This folder is the **Day 1 / Day 2 source of truth** for the TaskTreat AWS
infrastructure. Every VPC, EKS, RDS, ECR, and IAM resource the project uses is
declared here. **No infrastructure should be created by clicking through the
AWS Console.**

```
infra/terraform/
  bootstrap/                                # one-time S3 + DynamoDB for remote state
  modules/
    vpc/                                    # VPC, subnets, IGW, NAT, route tables
    ecr/                                    # one ECR repo per image
    iam/                                    # EKS cluster + node IAM roles
    eks/                                    # EKS cluster, managed node group, OIDC provider
    rds/                                    # private PostgreSQL + DB subnet group + SG
    route53/                                # Step 5: public hosted zone for the apex domain
    acm/                                    # Step 5: DNS-validated ACM certificate
    aws-load-balancer-controller-irsa/      # Step 5: IAM role/policy + IRSA trust for AWS LBC
  environments/
    dev/                                    # dev composition (calls every module)
```

---

## Prerequisites

- An AWS account you can deploy into.
- AWS CLI configured (`aws configure` or `AWS_PROFILE=...`) for that account.
- Terraform `>= 1.5.0` (`terraform -version`).
- `kubectl` (for post-apply validation).
- A region picked once and used everywhere. Default: `us-west-2`.

Cost note: this stack creates an EKS control plane (~$0.10/hr), a NAT Gateway
(~$0.045/hr + data), 2 × `t3.medium` workers, and a `db.t3.micro` RDS
instance. Expect a few US dollars per day while it is running. Run
`terraform destroy` when you are done.

---

## Step 1 — Bootstrap remote state (run once per AWS account)

The dev environment is configured to use an **S3 + DynamoDB** Terraform
backend. The bucket and lock table need to exist before
`environments/dev/terraform init` will succeed, so we create them with their
own tiny Terraform stack (`infra/terraform/bootstrap`) that uses local state.

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply
```

Note the outputs:

```
state_bucket = "tasktreat-tfstate-<aws-account-id>"
lock_table   = "tasktreat-tf-locks"
aws_region   = "us-west-2"
```

---

## Step 2 — Point the dev environment at that backend

Edit `environments/dev/backend.tf` and replace the placeholder bucket name
with the value printed above (or pass it on the command line when initing):

```bash
cd ../environments/dev

terraform init -reconfigure \
  -backend-config="bucket=tasktreat-tfstate-<aws-account-id>"
```

You should see `Successfully configured the backend "s3"!`.

---

## Step 3 — Provide variables (especially the DB password)

Two ways to supply the sensitive `db_password` variable.

**Option A — environment variable (recommended, never committed):**

```bash
export TF_VAR_db_password='replace-with-a-strong-password'
```

**Option B — local `terraform.tfvars` (gitignored):**

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set db_password = "..."
```

`terraform.tfvars` and any other `*.tfvars` files are excluded by the
project-level `.gitignore`, so secrets stay on your machine.

---

## Step 4 — Plan and apply

```bash
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

The first apply takes ~15–20 minutes (most of it is the EKS control plane
and node group). When it completes you should see outputs including
`cluster_name`, `cluster_endpoint`, `ecr_repository_urls`, and `rds_endpoint`.

---

## Step 5 — Validate

### Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name "$(terraform output -raw cluster_name)"

kubectl config current-context
kubectl cluster-info
kubectl get nodes
```

Expected: 2 worker nodes in `Ready` state.

### Confirm ECR repositories

```bash
aws ecr describe-repositories \
  --region us-west-2 \
  --query 'repositories[].repositoryName' \
  --output table
```

Expected names:

```
tasktreat-dev-frontend
tasktreat-dev-task-service
tasktreat-dev-wishlist-service
tasktreat-dev-reward-service
```

### Confirm RDS is private

```bash
aws rds describe-db-instances \
  --region us-west-2 \
  --query 'DBInstances[].[DBInstanceIdentifier,Endpoint.Address,PubliclyAccessible]' \
  --output table
```

`PubliclyAccessible` should be `False`. The endpoint is reachable only from
inside the VPC (i.e. EKS workers), which is exactly what we want.

---

## Day 2 — making changes

All updates go through Terraform. A few common Day 2 operations:

| Goal                                       | What to change                                                                                  |
|--------------------------------------------|-------------------------------------------------------------------------------------------------|
| Upgrade Kubernetes minor version           | `eks_cluster_version = "1.31"` then `terraform apply`. Node group inherits the same version.    |
| Patch the worker AMI (OS / CVE fixes)      | Set `eks_ami_release_version` to a newer EKS-optimized release and `terraform apply` (rolling). |
| Resize the node group                      | Update `eks_min_size` / `eks_max_size` (and re-create / scale via cluster autoscaler later).    |
| Add an ECR repo for a new microservice     | Add the bare name to `repository_names` in `module "ecr"`.                                      |
| Allow another security group to reach RDS  | Append its ID to `module.rds.allowed_security_group_ids`.                                       |

For every change: `terraform plan` first, review, then `terraform apply`.

---

## Tearing it down

```bash
cd infra/terraform/environments/dev
terraform destroy
```

Then, only if you also want to remove the remote-state bucket and lock table:

```bash
cd ../../bootstrap
terraform destroy
```

> The bootstrap bucket has versioning enabled. If `destroy` complains the
> bucket is not empty, empty it first (`aws s3 rm s3://<bucket> --recursive`
> and remove versioned objects via the AWS console / `aws s3api`) and rerun.

---

## Step 5 add-ons (DNS, TLS, ALB controller IRSA)

These three modules join the dev composition to back the public Ingress:

| Module                                    | Resources                                                                                                                                  |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `modules/route53`                         | `aws_route53_zone` for the apex (e.g. `tasktreat.dev`).                                                                                    |
| `modules/acm`                             | `aws_acm_certificate` (DNS validation), `aws_route53_record` for each validation entry, `aws_acm_certificate_validation` (waits for ISSUED). |
| `modules/aws-load-balancer-controller-irsa` | Customer-managed IAM policy (pinned upstream JSON), IAM role with EKS-OIDC trust, role/policy attachment.                                 |

Inputs added in `environments/dev`:

```hcl
domain_name   = "tasktreat.dev"
app_subdomain = "app"           # → app.tasktreat.dev
```

Outputs added in `environments/dev`:

| Output                                    | Used by                                                                |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `domain_name`, `app_fqdn`                 | scripts that build URLs.                                               |
| `route53_zone_id`                         | `scripts/upsert-app-dns.sh` (Route 53 alias UPSERT).                   |
| `route53_name_servers`                    | The four addresses to paste into Name.com.                             |
| `acm_certificate_arn`                     | `scripts/render-ingress-patch.sh` (Ingress annotation).                |
| `aws_load_balancer_controller_role_arn`   | `scripts/install-aws-lb-controller.sh` (Helm SA annotation).           |

After `terraform apply`, the human-in-the-loop step is to copy
`route53_name_servers` into Name.com so DNS for the domain (and the ACM
DNS validation Terraform created) actually resolves through Route 53.

See `docs/step5-ingress-dns-https.md` for the full runbook.

---

## What this step intentionally does NOT do

The following all live in later steps:

- Building / pushing the Docker images to ECR
- Kubernetes manifests / Helm charts for the app
- ExternalDNS / Terraform-managed Ingress alias record
- Prometheus / Grafana / Loki
- GitHub Actions CI/CD and the GitHub OIDC IAM role
- Database migrations
- Canary rollouts

The IAM module is structured so the GitHub Actions OIDC role can be added
later without touching the cluster wiring.
