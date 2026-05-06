# TaskTreat

> A productivity board that rewards you for completing tasks by selecting a weekly treat from your personal wishlist.

TaskTreat is a Jira-style task tracker with a reward twist. You manage tasks across four Kanban columns (Backlog, Todo, Doing, Done) and maintain a wishlist of items you want to buy. Each week, the app picks a random reward item you've earned by completing tasks.

This repo currently covers **Steps 1–5** of the project:

- **Step 1** — application architecture, frontend, and three backend microservices.
- **Step 2** — `docker-compose.yml` for local Postgres + multi-stage Dockerfiles per service / for the frontend.
- **Step 3** — Terraform-managed AWS infrastructure (`infra/terraform/`): VPC, ECR, IAM, EKS, RDS.
- **Step 4** — Kustomize-based Kubernetes manifests (`k8s/`) deploying the four images to EKS.
- **Step 5** — Public ingress on a custom HTTPS domain (`https://app.tasktreat.dev`):
  Route 53 hosted zone, ACM certificate, AWS Load Balancer Controller (IRSA), single
  ALB doing path-based routing into the four ClusterIP services. See
  [`docs/step5-ingress-dns-https.md`](docs/step5-ingress-dns-https.md).

CI/CD, observability, canary rollouts, and chaos defense live in later steps.

## Architecture at a glance

```
React Frontend (Vite, port 5173)
   |
   | HTTP /api/...
   v
+-----------------------+----------------------------+
| /api/tasks    -> task-service     (port 4001)      |
| /api/wishlist -> wishlist-service (port 4002)      |
| /api/rewards  -> reward-service   (port 4003)      |
+----------------------------------------------------+
   |
   v
PostgreSQL (single shared DB; one logical owner per table)
```

See [`docs/architecture.md`](docs/architecture.md), [`docs/api-contracts.md`](docs/api-contracts.md), and [`docs/reward-logic.md`](docs/reward-logic.md) for full detail.

## Repository layout

```
tasktreat/
  package.json              # npm workspaces root
  docker-compose.yml        # Postgres only, port 5432
  .env.example              # shared DATABASE_URL example
  frontend/                 # Vite + React + TS + Tailwind + shadcn/ui
  services/
    task-service/           # port 4001, owns tasks table
    wishlist-service/       # port 4002, owns wishlist_items table
    reward-service/         # port 4003, owns weekly_rewards table
  docs/
```

## Prerequisites

- Node.js 20+
- npm 10+
- Docker (for local Postgres)

## First-time setup

```bash
cd tasktreat
npm install                 # installs all workspaces

npm run dev:db              # starts Postgres on :5432

# Each service has its own Prisma schema; create tables for all three.
npm run db:migrate

# Optional but recommended for the demo flow
npm run db:seed
```

## Day-to-day

```bash
npm run dev                 # runs all 3 services + frontend concurrently
```

Or run them individually:

```bash
npm run dev:task            # task-service on :4001
npm run dev:wishlist        # wishlist-service on :4002
npm run dev:reward          # reward-service on :4003
npm run dev:frontend        # frontend on :5173
```

The frontend's Vite dev server proxies `/api/tasks`, `/api/wishlist`, and `/api/rewards` to the corresponding service ports, so the React app only ever talks to `/api/...`.

## Health checks

Each service exposes `GET /health`:

```bash
curl localhost:4001/health
curl localhost:4002/health
curl localhost:4003/health
```

## Demo flow

1. Open the frontend at `http://localhost:5173`.
2. Move a task to **Done** to bump the completed-this-week counter.
3. Add a wishlist item or two.
4. Click **Generate Weekly Treat** in the reward panel — `reward-service` calls both other services and picks a weighted-random eligible item.
5. View **Reward History** to see prior weeks.
