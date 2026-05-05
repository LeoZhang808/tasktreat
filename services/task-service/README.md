# task-service

Owns task lifecycle and the `tasks` table.

- **Port:** 4001
- **Public route prefix:** `/api/tasks`
- **Internal route prefix:** `/internal/tasks`
- **Owned table:** `tasks`

## Endpoints

### Public

| Method | Path                       | Purpose                                              |
| ------ | -------------------------- | ---------------------------------------------------- |
| GET    | `/api/tasks`               | List tasks. Optional `?status=BACKLOG\|TODO\|DOING\|DONE` |
| GET    | `/api/tasks/:id`           | Get one task                                         |
| POST   | `/api/tasks`               | Create a task                                        |
| PATCH  | `/api/tasks/:id`           | Update title / description / priority                |
| DELETE | `/api/tasks/:id`           | Delete a task                                        |
| PATCH  | `/api/tasks/:id/status`    | Move a task to a new status (stamps `completedAt` if first transition into `DONE`) |

### Internal

| Method | Path                                                     | Purpose                                |
| ------ | -------------------------------------------------------- | -------------------------------------- |
| GET    | `/internal/tasks/completed-count?weekStart=&weekEnd=`    | Number of tasks completed in `[weekStart, weekEnd]` (inclusive, UTC) |

### Health

- `GET /health` → `{ "status": "ok", "service": "task-service" }`

## Local development

```bash
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

Required env vars (see `../../.env.example`):

- `DATABASE_URL`
- `PORT` (default 4001)
- `NODE_ENV`

## Build / run

```bash
npm run build
npm start
```

## Docker

```bash
docker build -t tasktreat/task-service .
docker run --rm -p 4001:4001 \
  -e DATABASE_URL=postgresql://tasktreat:tasktreat@host.docker.internal:5432/tasktreat \
  tasktreat/task-service
```
