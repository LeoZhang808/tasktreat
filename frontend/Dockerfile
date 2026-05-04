# Build context: repo root (see docker-compose.yml).
# All COPY paths are therefore relative to the repo root.

FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./

COPY frontend/package.json ./frontend/package.json

RUN npm ci --workspace=frontend --include-workspace-root

COPY frontend/tsconfig.json frontend/tsconfig.app.json frontend/tsconfig.node.json ./frontend/
COPY frontend/vite.config.ts frontend/postcss.config.js frontend/tailwind.config.js frontend/index.html ./frontend/
COPY frontend/src ./frontend/src
COPY frontend/public ./frontend/public

RUN npm --workspace=frontend run build


FROM nginx:1.27-alpine AS runtime
COPY --from=builder /app/frontend/dist /usr/share/nginx/html
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
