# TaskTreat — Reward logic

This is the canonical description of how `reward-service` decides the weekly treat.

## Inputs

- `completedTasks` — number of `tasks` rows where `status = DONE` and `completed_at` falls inside `[weekStart, weekEnd]` (inclusive, UTC). Source: `task-service` `/internal/tasks/completed-count`.
- Eligible wishlist items — items where `price <= rewardBudget` and `is_purchased = false`. Source: `wishlist-service` `/internal/wishlist/eligible`.
- `REWARD_VALUE_PER_TASK` — environment variable on `reward-service`, default **`5`**.

## Week boundaries

Weeks are Monday through Sunday in UTC (ISO-style). Both bounds are formatted as `YYYY-MM-DD`. The unique constraint on `weekly_rewards.week_start` enforces "one reward per week" for the MVP.

## Budget formula

```
weekly_reward_budget = completed_tasks_this_week × REWARD_VALUE_PER_TASK
```

This is a **hard** cap — items priced above the budget are excluded from the draw, not discounted.

Example:

```
completed_tasks_this_week = 12
REWARD_VALUE_PER_TASK     = 5
weekly_reward_budget      = 60
```

## Eligibility

A wishlist item is eligible if **both** are true:

```
item.price <= weekly_reward_budget
item.is_purchased = false
```

Already-purchased items are filtered out. There is no "minimum budget" rule — if `weekly_reward_budget = 0`, no item can be eligible because every item has `price > 0`.

## Weighted random selection

For each eligible item:

```
weight = item.price
total_weight = sum of all eligible item weights
```

Selection algorithm:

```
r = uniformRandom(0, total_weight)
cumulative = 0
for item in items:
  cumulative += item.price
  if r < cumulative:
    return item
```

This means more expensive items have a proportionally higher chance, but cheaper items can still be picked. (See `services/reward-service/src/lib/select.ts`.)

### Worked example

Eligible items:

| Item     | Price |
| -------- | ----- |
| Coffee   | $5    |
| Book     | $20   |
| Keyboard | $50   |

```
total_weight = 5 + 20 + 50 = 75
P(Coffee)   = 5  / 75 ≈ 6.7%
P(Book)     = 20 / 75 ≈ 26.7%
P(Keyboard) = 50 / 75 ≈ 66.7%
```

The keyboard has the highest chance, but coffee is still in the running.

## Edge cases and responses

| Situation                                | Effect on `POST /api/rewards/generate-weekly`                          |
| ---------------------------------------- | ----------------------------------------------------------------------- |
| `completedTasks === 0`                   | `200 { reward: null, reason: "no_completed_tasks" }`                   |
| `eligibleItems.length === 0`             | `200 { reward: null, reason: "no_eligible_items" }`                    |
| Reward already exists for week (no force)| `200 { reward: <existing>, reason: "already_generated" }`              |
| Reward already exists, `force: true`     | Existing row deleted, new selection inserted, `regenerated: true`      |
| Eligible items exist                      | `201` with newly-inserted reward row                                   |

## Snapshots

When a reward is saved, the chosen item's `name` and `price` are stored on the `weekly_rewards` row as `wishlist_item_name_snapshot` / `wishlist_item_price_snapshot`. This means reward history stays accurate even if a wishlist item is later renamed, repriced, or deleted.

## Configuration knobs

| Env var                  | Default | Effect                                  |
| ------------------------ | ------- | --------------------------------------- |
| `REWARD_VALUE_PER_TASK`  | `5`     | Multiplier in the budget formula        |

## Triggering

For the MVP, reward generation is **manually triggered** by the **Generate Weekly Treat** button in the frontend. A scheduled weekly trigger (cron, Kubernetes CronJob, etc.) can be layered on later without changing the API.
