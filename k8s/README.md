# TaskTreat — Kubernetes Manifests (Steps 4 + 5)

This directory ships the Kustomize manifests that deploy TaskTreat to the
`tasktreat-dev-eks` EKS cluster created in Step 3.

```
k8s/
  base/                                # plain, environment-agnostic manifests
    namespace.yaml
    configmap.yaml
    secrets.example.yaml               # NEVER applied as-is; template only
    ingress.yaml                       # Step 5: path-based ALB Ingress
    kustomization.yaml
    task-service/
    wishlist-service/
    reward-service/
    frontend/
  overlays/
    dev/
      kustomization.yaml               # namespace + ECR image overrides + ingress patch
      ingress-patch.yaml.template      # Step 5: rendered → ingress-patch.yaml (gitignored)
```

The dev overlay is the only one that should be `kubectl apply`-ed for Step 4.

---

## Namespaces are bootstrapped out-of-band

`Namespace` is a cluster-scoped resource and the GitHub Actions deploy role
only has `AmazonEKSAdminPolicy` *inside* each namespace, not over it. To
keep `kubectl apply -k` Forbidden-free, the base kustomization deliberately
does **not** render `namespace.yaml`. Create the four namespaces once
(from an admin principal) before any pipeline runs:

```bash
kubectl create namespace tasktreat-dev   --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tasktreat-qa    --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tasktreat-uat   --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tasktreat-prod  --dry-run=client -o yaml | kubectl apply -f -
```

`namespace.yaml` (base) and the per-overlay `namespace-patch.yaml` files are
kept as documentation; nothing references them at render time.

---

## Prerequisites

- `kubectl` configured against the EKS cluster:
  ```bash
  aws eks update-kubeconfig --region us-west-2 --name tasktreat-dev-eks
  kubectl config current-context     # should reference tasktreat-dev-eks
  kubectl get nodes                  # 2 Ready nodes expected
  ```
- All four images pushed to ECR with the `dev-latest` tag (see
  `scripts/build-and-push-dev.sh`).

---

## Deploy

1. Build and push images.

   ```bash
   ./scripts/ecr-login.sh
   ./scripts/build-and-push-dev.sh
   ```

2. Create the namespace (the overlay also includes it, but creating it
   explicitly first makes the next `kubectl create secret` work).

   ```bash
   kubectl apply -k k8s/overlays/dev   # idempotent; creates namespace too
   ```

3. Create the database secret out-of-band. The secret is **not** committed.
   Each service connects to its own Postgres schema, so we provision one
   key per service:

   ```bash
   PASSWORD='<the RDS master password>'
   ENDPOINT='tasktreat-dev-postgres.c5emyy2yg5as.us-west-2.rds.amazonaws.com'

   kubectl create secret generic tasktreat-db-secret \
     --namespace tasktreat-dev \
     --from-literal=DATABASE_URL_TASK="postgresql://tasktreat:${PASSWORD}@${ENDPOINT}:5432/tasktreat?schema=task" \
     --from-literal=DATABASE_URL_WISHLIST="postgresql://tasktreat:${PASSWORD}@${ENDPOINT}:5432/tasktreat?schema=wishlist" \
     --from-literal=DATABASE_URL_REWARD="postgresql://tasktreat:${PASSWORD}@${ENDPOINT}:5432/tasktreat?schema=reward"
   ```

4. Restart the deployments so the new env vars take effect (only needed if
   the secret was created after the first `apply`):

   ```bash
   kubectl rollout restart deployment -n tasktreat-dev
   ```

5. Watch the rollout:

   ```bash
   kubectl get pods -n tasktreat-dev -w
   ```

---

## Verify

```bash
./scripts/verify-eks.sh
```

Then port-forward each service in its own terminal:

```bash
kubectl port-forward svc/task-service     4001:4001 -n tasktreat-dev
kubectl port-forward svc/wishlist-service 4002:4002 -n tasktreat-dev
kubectl port-forward svc/reward-service   4003:4003 -n tasktreat-dev
kubectl port-forward svc/frontend         5173:80   -n tasktreat-dev
```

Health checks:

```bash
curl http://localhost:4001/health
curl http://localhost:4002/health
curl http://localhost:4003/health
```

The single most important Step 4 proof — that `reward-service` can reach
`task-service` and `wishlist-service` over in-cluster DNS — is the reward
generation endpoint:

```bash
curl -X POST http://localhost:4003/api/rewards/generate-weekly
```

---

## How the manifests fit together

- `namespace.yaml` creates `tasktreat-dev`.
- `configmap.yaml` exposes non-secret runtime config (service URLs,
  `NODE_ENV`, `REWARD_VALUE_PER_TASK`).
- `tasktreat-db-secret` (created manually) holds one `DATABASE_URL_<svc>`
  per service. Each Deployment maps its own key to the env var
  `DATABASE_URL`.
- Each service ships a `Deployment` and a `ClusterIP` `Service`. Backends
  expose their HTTP port (4001/4002/4003); the frontend exposes nginx on
  port 80. The frontend's `nginx.conf` proxies `/api/*` to the backend
  ClusterIPs, so once Ingress lands in Step 5 the same routes work
  externally.
- The dev overlay (`overlays/dev/kustomization.yaml`) does two jobs:
  1. Pins everything to the `tasktreat-dev` namespace.
  2. Rewrites the short image references in the base (e.g.
     `tasktreat-dev-task-service:dev-latest`) to the real ECR URLs. To
     promote a new image, bump `newTag` here instead of editing every
     Deployment.

---

## Image tagging

Step 4 uses a single mutable tag, `dev-latest`. To force EKS to pull a
freshly pushed image after rebuilding, either:

- Bump `newTag` in the overlay to a unique value (Git SHA, etc.), or
- Restart the deployment: `kubectl rollout restart deployment -n tasktreat-dev`.

`imagePullPolicy: Always` is already set on each Deployment so kubelet
will re-pull `dev-latest` on every pod start.

CI/CD in a later step will replace `dev-latest` with Git SHA tags.

---

## Step 5 — Public Ingress / DNS / HTTPS

Once Step 4 is healthy, run the full Step 5 runbook (full version in
`docs/step5-ingress-dns-https.md`):

```bash
# 1. Provision Route 53 zone, ACM cert, and AWS LBC IRSA via Terraform.
( cd infra/terraform/environments/dev && terraform apply )

# 2. (One-time) Paste route53_name_servers into Name.com so DNS for
#    tasktreat.dev resolves through Route 53.
( cd infra/terraform/environments/dev && terraform output route53_name_servers )

# 3. Install the AWS Load Balancer Controller into kube-system.
./scripts/install-aws-lb-controller.sh

# 4. Render the dev Ingress patch from terraform output and apply.
./scripts/deploy-ingress.sh

# 5. UPSERT the Route 53 alias for app.tasktreat.dev → ALB.
./scripts/upsert-app-dns.sh

# 6. Verify everything end-to-end.
./scripts/verify-step5.sh
```

The dev overlay's `ingress-patch.yaml` is **generated** from the committed
`ingress-patch.yaml.template`. The rendered file is gitignored so the
environment-specific ACM ARN is never accidentally committed. Re-run
`scripts/render-ingress-patch.sh` after every `terraform apply` that
changes the certificate.

---

## Step 7 — Canary in production (Argo Rollouts)

`overlays/prod/` swaps the four base Deployments for Argo Rollouts so
production releases use a progressive (canary) strategy:
`20% → pause 60s → 50% → pause 60s → 100%`. `dev`, `qa`, and `uat` keep
using plain Deployments.

- `overlays/prod/rollouts/*-rollout.yaml` — one Rollout per service.
- `overlays/prod/pdb/*-pdb.yaml` — PodDisruptionBudgets (`minAvailable: 1`).
- `overlays/prod/deployment-delete-*.yaml` — `$patch: delete` patches that
  strip the base Deployments out of the prod overlay so we don't run both
  a Deployment and a Rollout for the same service.

Install the controller once per cluster:

```bash
./scripts/install-argo-rollouts.sh
```

Demo a rollout (run `scripts/verify-zero-downtime.sh` in another terminal
to prove no dropped requests):

```bash
./scripts/canary-demo.sh task-service v1.0.1
```

Full write-up: [`docs/step7-canary-zero-downtime.md`](../docs/step7-canary-zero-downtime.md).

---

## Migrations note

Each backend image currently runs
`npx prisma migrate deploy && node dist/index.js` at startup. With a
single replica per service that's fine. A later step will extract
migrations into a dedicated `Job` so multi-replica rollouts don't race
on schema changes.
