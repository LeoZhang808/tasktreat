# TaskTreat — API contracts

Conventions:

- All request and response bodies are JSON.
- Timestamps are ISO 8601 strings (UTC).
- Money fields (`price`, budgets, snapshots) are sent as plain numbers (USD).
- Validation errors return `400 { "error": "validation_error", "issues": [...] }`.
- Not-found returns `404 { "error": "<resource> not found" }`.
- Unhandled errors return `500 { "error": "internal_error", "message": "..." }`.

---

## task-service (`/api/tasks`)

### Task object

```json
{
  "id": 1,
  "title": "Finish DevOps project architecture",
  "description": "Lock in the Step 1 architecture for TaskTreat.",
  "status": "DONE",
  "priority": "HIGH",
  "createdAt": "2026-05-01T18:30:00.000Z",
  "updatedAt": "2026-05-01T18:30:00.000Z",
  "completedAt": "2026-05-01T18:30:00.000Z"
}
```

`status ∈ {BACKLOG, TODO, DOING, DONE}`. `priority ∈ {LOW, MEDIUM, HIGH} | null`.

### Endpoints

#### `GET /api/tasks`

Optional query: `?status=BACKLOG|TODO|DOING|DONE`.

```json
{ "count": 5, "tasks": [ { "id": 1, "title": "…", "status": "TODO", ... } ] }
```

#### `GET /api/tasks/:id`

Returns a single Task.

#### `POST /api/tasks`

Body:

```json
{ "title": "Write spec", "description": "Optional", "priority": "MEDIUM", "status": "BACKLOG" }
```

`title` is required. `status` defaults to `BACKLOG`. If `status` is sent as `DONE`, `completedAt` is stamped immediately.

Returns `201` with the created Task.

#### `PATCH /api/tasks/:id`

Partial update of `title`, `description`, `priority`. Status is changed only via `/status`.

#### `DELETE /api/tasks/:id`

Returns `204`.

#### `PATCH /api/tasks/:id/status`

Body:

```json
{ "status": "DOING" }
```

Behavior:

- If new `status === "DONE"` and `completedAt` is null, `completedAt` is set to `now()`.
- Moving back out of DONE does **not** clear `completedAt` (MVP rule).

Returns the updated Task.

### Internal: `GET /internal/tasks/completed-count`

Query: `weekStart=YYYY-MM-DD&weekEnd=YYYY-MM-DD` (both required, inclusive, treated as UTC).

```json
{ "weekStart": "2026-05-04", "weekEnd": "2026-05-10", "completedTasks": 12 }
```

### `GET /health`

```json
{ "status": "ok", "service": "task-service" }
```

---

## wishlist-service (`/api/wishlist`)

### WishlistItem object

```json
{
  "id": 3,
  "name": "Mechanical keyboard",
  "price": 55.0,
  "category": "Tech",
  "url": "https://example.com/keyboard",
  "isPurchased": false,
  "createdAt": "2026-05-04T12:00:00.000Z",
  "updatedAt": "2026-05-04T12:00:00.000Z"
}
```

### Endpoints

#### `GET /api/wishlist`

```json
{ "count": 5, "items": [ { ... } ] }
```

#### `GET /api/wishlist/:id`

Returns a single WishlistItem.

#### `POST /api/wishlist`

Body:

```json
{ "name": "Book", "price": 20, "category": "Reading", "url": "https://example.com/book" }
```

`name` and `price > 0` are required. `category` and `url` optional.

Returns `201` with the created item.

#### `PATCH /api/wishlist/:id`

Partial update of `name`, `price`, `category`, `url`, `isPurchased`.

#### `DELETE /api/wishlist/:id`

Returns `204`.

#### `PATCH /api/wishlist/:id/purchased`

Body: `{ "isPurchased": true }` or `{ "isPurchased": false }`. Returns the updated item.

### Internal: `GET /internal/wishlist/eligible`

Query: `maxPrice=<number>` (required, ≥ 0).

```json
{
  "maxPrice": 60,
  "count": 3,
  "items": [
    { "id": 1, "name": "Coffee", "price": 6.0, "category": "Lifestyle", "url": null },
    { "id": 2, "name": "Book",   "price": 20.0, "category": "Reading",   "url": "https://..." },
    { "id": 3, "name": "Keyboard", "price": 55.0, "category": "Tech",   "url": "https://..." }
  ]
}
```

Eligibility: `price <= maxPrice AND is_purchased = false`.

### `GET /health`

```json
{ "status": "ok", "service": "wishlist-service" }
```

---

## reward-service (`/api/rewards`)

### Reward object

```json
{
  "id": 7,
  "wishlistItemId": 3,
  "wishlistItemName": "Mechanical keyboard",
  "wishlistItemPrice": 55.0,
  "weekStart": "2026-05-04",
  "weekEnd": "2026-05-10",
  "tasksCompleted": 12,
  "rewardValuePerTask": 5,
  "rewardBudget": 60,
  "selectionWeight": 55,
  "selectedAt": "2026-05-09T17:00:00.000Z"
}
```

The item name and price are **snapshots** taken at selection time so historical rewards stay correct even if the wishlist item is later edited or deleted.

### Endpoints

#### `GET /api/rewards/current`

Returns the reward for the current ISO week, or `null` if none has been generated yet.

```json
{ "weekStart": "2026-05-04", "reward": { ... } | null }
```

#### `POST /api/rewards/generate-weekly`

Body (optional):

```json
{ "force": false }
```

Possible responses:

- New reward generated:

```json
{ "weekStart": "2026-05-04", "weekEnd": "2026-05-10", "reward": { ... }, "regenerated": false }
```

- Already generated, `force=false`:

```json
{ "weekStart": "...", "weekEnd": "...", "reward": { ... }, "regenerated": false, "reason": "already_generated" }
```

- No completed tasks this week:

```json
{ "weekStart": "...", "weekEnd": "...", "reward": null, "reason": "no_completed_tasks", "tasksCompleted": 0, "rewardBudget": 0 }
```

- No eligible items within budget:

```json
{ "weekStart": "...", "weekEnd": "...", "reward": null, "reason": "no_eligible_items", "tasksCompleted": 12, "rewardBudget": 60 }
```

When `force=true`, any existing reward for the current week is replaced (the unique `week_start` invariant is preserved).

#### `GET /api/rewards/history`

```json
{ "count": 4, "rewards": [ { ... newest first ... } ] }
```

#### `GET /api/rewards/eligibility`

Runs the calculation steps without writing.

```json
{
  "weekStart": "2026-05-04",
  "weekEnd": "2026-05-10",
  "tasksCompleted": 12,
  "rewardValuePerTask": 5,
  "rewardBudget": 60,
  "eligibleItemCount": 3,
  "eligibleItems": [
    { "id": 1, "name": "Coffee", "price": 6.0, "category": "Lifestyle", "url": null }
  ]
}
```

### `GET /health`

```json
{ "status": "ok", "service": "reward-service" }
```
