# Build context: repo root (see docker-compose.yml).
# All COPY paths are therefore relative to the repo root.

FROM node:20-alpine AS builder
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app

COPY package.json package-lock.json ./

COPY services/wishlist-service/package.json ./services/wishlist-service/package.json

COPY services/wishlist-service/prisma ./services/wishlist-service/prisma

RUN npm ci --workspace=wishlist-service --include-workspace-root

COPY services/wishlist-service/tsconfig.json ./services/wishlist-service/tsconfig.json
COPY services/wishlist-service/src ./services/wishlist-service/src

RUN npm --workspace=wishlist-service run build


FROM node:20-alpine AS runtime
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
COPY services/wishlist-service/package.json ./services/wishlist-service/package.json
COPY services/wishlist-service/prisma ./services/wishlist-service/prisma

RUN npm ci --workspace=wishlist-service --include-workspace-root --omit=dev

COPY --from=builder /app/services/wishlist-service/dist ./services/wishlist-service/dist
COPY --from=builder /app/services/wishlist-service/prisma/generated ./services/wishlist-service/prisma/generated

WORKDIR /app/services/wishlist-service
EXPOSE 4002
CMD ["sh", "-c", "npx prisma migrate deploy --schema prisma/schema.prisma && node dist/index.js"]
