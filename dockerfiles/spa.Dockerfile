FROM node:20-bookworm-slim AS base

RUN corepack enable

WORKDIR /app

FROM base AS builder

COPY . .

RUN NODE_TLS_REJECT_UNAUTHORIZED=0 pnpm install --frozen-lockfile
RUN pnpm --filter @telecom/spa build

FROM base AS runner

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

WORKDIR /app

COPY --from=builder /app/apps/spa/.next/standalone ./
COPY --from=builder /app/apps/spa/.next/static ./apps/spa/.next/static
COPY --from=builder /app/apps/spa/public ./apps/spa/public

CMD ["node", "apps/spa/server.js"]
