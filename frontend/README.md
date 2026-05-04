# frontend

TaskTreat web UI: a single-page dashboard with a Kanban task board, a wishlist, and a weekly treat panel.

- **Stack:** Vite + React 18 + TypeScript + Tailwind CSS + shadcn/ui
- **Dev port:** 5173
- **Talks to:** `/api/tasks`, `/api/wishlist`, `/api/rewards`

## Local development

```bash
npm install
npm run dev
```

The Vite dev server proxies the three `/api/*` prefixes to the corresponding backend services on `:4001`, `:4002`, and `:4003`. Make sure those services are running (or use `npm run dev` from the repo root to start everything together).

## Build / preview

```bash
npm run build
npm run preview
```

The production build is a static SPA served by nginx in the Docker image.

## Layout

```
src/
  components/
    board/         # TaskBoard, TaskCard, TaskFormDialog
    wishlist/      # WishlistSection, WishlistItemForm
    reward/        # WeeklyTreatPanel, RewardHistoryDialog
    ui/            # shadcn/ui primitives (Button, Card, Dialog, ...)
  hooks/           # useTasks, useWishlist, useRewards
  lib/             # api fetch wrapper, formatting helpers
  pages/Dashboard.tsx
  index.css        # tailwind layers + theme tokens
  main.tsx
```

## Env

| Var                  | Default | Purpose                          |
| -------------------- | ------- | -------------------------------- |
| `VITE_API_BASE_URL`  | `/api`  | Where API requests are sent      |
