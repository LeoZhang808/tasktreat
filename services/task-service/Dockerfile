# Build context: repo root (see docker-compose.yml).
# All COPY paths are therefore relative to the repo root.

FROM node:20-alpine AS builder
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app

# Root manifests first so npm understands the workspace tree before any source
# changes invalidate the cache.
COPY package.json package-lock.json ./

# This service's manifest. Required so `npm ci -w task-service` can resolve
# the workspace from the lockfile.
COPY services/task-service/package.json ./services/task-service/package.json

# Prisma schema is needed by the build script (which runs `prisma generate`).
COPY services/task-service/prisma ./services/task-service/prisma

# Deterministic, workspace-scoped install. `--include-workspace-root` brings in
# any root-level deps that the workspace transitively relies on.
RUN npm ci --workspace=task-service --include-workspace-root

COPY services/task-service/tsconfig.json ./services/task-service/tsconfig.json
COPY services/task-service/src ./services/task-service/src

RUN npm --workspace=task-service run build


FROM node:20-alpine AS runtime
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
COPY services/task-service/package.json ./services/task-service/package.json
COPY services/task-service/prisma ./services/task-service/prisma

RUN npm ci --workspace=task-service --include-workspace-root --omit=dev

COPY --from=builder /app/services/task-service/dist ./services/task-service/dist
COPY --from=builder /app/services/task-service/prisma/generated ./services/task-service/prisma/generated

WORKDIR /app/services/task-service
EXPOSE 4001
CMD ["sh", "-c", "npx prisma migrate deploy --schema prisma/schema.prisma && node dist/index.js"]
