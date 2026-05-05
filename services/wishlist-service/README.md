# wishlist-service

Owns the user's wishlist items and the `wishlist_items` table.

- **Port:** 4002
- **Public route prefix:** `/api/wishlist`
- **Internal route prefix:** `/internal/wishlist`
- **Owned table:** `wishlist_items`

## Endpoints

### Public

| Method | Path                              | Purpose                            |
| ------ | --------------------------------- | ---------------------------------- |
| GET    | `/api/wishlist`                   | List wishlist items                |
| GET    | `/api/wishlist/:id`               | Get one wishlist item              |
| POST   | `/api/wishlist`                   | Create a wishlist item             |
| PATCH  | `/api/wishlist/:id`               | Update name / price / category / url / purchased |
| DELETE | `/api/wishlist/:id`               | Delete a wishlist item             |
| PATCH  | `/api/wishlist/:id/purchased`     | Mark purchased / unpurchased       |

### Internal

| Method | Path                                      | Purpose                                     |
| ------ | ----------------------------------------- | ------------------------------------------- |
| GET    | `/internal/wishlist/eligible?maxPrice=N`  | Items where `price <= maxPrice` and `is_purchased = false` |

### Health

- `GET /health` → `{ "status": "ok", "service": "wishlist-service" }`

## Local development

```bash
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

Required env vars:

- `DATABASE_URL`
- `PORT` (default 4002)
- `NODE_ENV`

## Docker

```bash
docker build -t tasktreat/wishlist-service .
docker run --rm -p 4002:4002 \
  -e DATABASE_URL=postgresql://tasktreat:tasktreat@host.docker.internal:5432/tasktreat \
  tasktreat/wishlist-service
```
