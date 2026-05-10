# TaskTreat

Task tracker with a wishlist: you finish tasks, you earn a random weekly treat from items you said you want.

Stack: React frontend (Vite), three Node services (task, wishlist, reward), Postgres. In AWS everything runs on EKS with RDS; Terraform owns the cloud bits. Details live in the other READMEs in this repo — this file is just the quick picture and how to run locally.

Rough shape:

```
Frontend (Vite)
  -> /api/tasks     -> task-service     :4001
  -> /api/wishlist  -> wishlist-service :4002
  -> /api/rewards   -> reward-service   :4003  (calls the other two over HTTP)
  -> Postgres (one DB; each service owns its own tables / Prisma schema)
```

Where to read more:

- `infra/terraform/README.md` — VPC, EKS, RDS, IAM, DNS, certs, remote state, Day 2 AMI bumps.
- `k8s/README.md` — manifests, overlays (dev/qa/uat/prod), ingress and HTTPS, prod canary rollouts.
- `frontend/README.md` — UI bits if you care.

CI/CD is `.github/workflows/` (dev on push, QA nightly, UAT when you merge to main with RC in the commit message, prod on version tags). Monitoring is Helm under `infra/helm/monitoring/` plus `k8s/monitoring/`; wire secrets with `scripts/bootstrap-monitoring-secrets.sh` once you read the comments in the values file.

Layout:

```
tasktreat/
  package.json
  docker-compose.yml    # local Postgres only
  frontend/
  services/
    task-service/
    wishlist-service/
    reward-service/
  infra/terraform/
  k8s/
```

## Local dev

Need Node 20+, npm, Docker.

```
cd tasktreat
npm install
npm run dev:db
npm run db:migrate
npm run db:seed    # optional
npm run dev        # all four processes
```

Single services: `npm run dev:task`, `dev:wishlist`, `dev:reward`, `dev:frontend`. Vite proxies `/api/*` to the right port.

Health:

```
curl localhost:4001/health
curl localhost:4002/health
curl localhost:4003/health
```

Quick demo: open http://localhost:5173, move a task to Done, add wishlist items, hit Generate Weekly Treat, check Reward History.
