# Build context: repo root (see docker-compose.yml).
# All COPY paths are therefore relative to the repo root.

FROM node:20-alpine AS builder
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app

COPY package.json package-lock.json ./

COPY services/reward-service/package.json ./services/reward-service/package.json

COPY services/reward-service/prisma ./services/reward-service/prisma

RUN npm ci --workspace=reward-service --include-workspace-root

COPY services/reward-service/tsconfig.json ./services/reward-service/tsconfig.json
COPY services/reward-service/src ./services/reward-service/src

RUN npm --workspace=reward-service run build


FROM node:20-alpine AS runtime
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
COPY services/reward-service/package.json ./services/reward-service/package.json
COPY services/reward-service/prisma ./services/reward-service/prisma

RUN npm ci --workspace=reward-service --include-workspace-root --omit=dev

COPY --from=builder /app/services/reward-service/dist ./services/reward-service/dist
COPY --from=builder /app/services/reward-service/prisma/generated ./services/reward-service/prisma/generated

WORKDIR /app/services/reward-service
EXPOSE 4003
CMD ["sh", "-c", "npx prisma migrate deploy --schema prisma/schema.prisma && node dist/index.js"]
