# reward-service

Owns weekly reward logic and the `weekly_rewards` table. Calls `task-service` and `wishlist-service` over HTTP — never touches their tables directly.

- **Port:** 4003
- **Public route prefix:** `/api/rewards`
- **Owned table:** `weekly_rewards`
- **Upstream services:** `task-service`, `wishlist-service`

## Endpoints

| Method | Path                            | Purpose                                                            |
| ------ | ------------------------------- | ------------------------------------------------------------------ |
| GET    | `/api/rewards/current`          | The reward chosen for the current ISO week, if one exists          |
| POST   | `/api/rewards/generate-weekly`  | Generate a reward for the current week. Body: `{ "force": false }` |
| GET    | `/api/rewards/history`          | Past weekly rewards, newest first                                  |
| GET    | `/api/rewards/eligibility`      | Completed-task count, budget, and eligible items without writing   |
| GET    | `/health`                       | Liveness probe                                                     |

## Reward formula

```
weekly_reward_budget = completed_tasks_this_week × REWARD_VALUE_PER_TASK
```

Eligibility per wishlist item:

```
price <= weekly_reward_budget AND is_purchased = false
```

Selection: weighted random where `weight = item.price`. See [`docs/reward-logic.md`](../../docs/reward-logic.md).

## Local development

```bash
npm install
npm run db:migrate
npm run dev
```

Required env vars:

- `DATABASE_URL`
- `PORT` (default 4003)
- `TASK_SERVICE_URL` (default `http://localhost:4001`)
- `WISHLIST_SERVICE_URL` (default `http://localhost:4002`)
- `REWARD_VALUE_PER_TASK` (default 5)
- `NODE_ENV`

## Docker

```bash
docker build -t tasktreat/reward-service .
docker run --rm -p 4003:4003 \
  -e DATABASE_URL=postgresql://tasktreat:tasktreat@host.docker.internal:5432/tasktreat \
  -e TASK_SERVICE_URL=http://host.docker.internal:4001 \
  -e WISHLIST_SERVICE_URL=http://host.docker.internal:4002 \
  -e REWARD_VALUE_PER_TASK=5 \
  tasktreat/reward-service
```
