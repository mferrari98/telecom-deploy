FROM node:20-bookworm-slim AS base

RUN corepack enable

WORKDIR /app

FROM base AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY . .

ARG INSECURE_TLS_BUILD=0
RUN if [ "${INSECURE_TLS_BUILD}" = "1" ]; then \
      NODE_TLS_REJECT_UNAUTHORIZED=0 pnpm install --frozen-lockfile; \
    else \
      pnpm install --frozen-lockfile; \
    fi
RUN pnpm --filter @telecom/spa build

FROM base AS runner

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

WORKDIR /app

COPY --from=builder --chown=node:node /app/apps/spa/.next/standalone ./
COPY --from=builder --chown=node:node /app/apps/spa/.next/static ./apps/spa/.next/static
COPY --from=builder --chown=node:node /app/apps/spa/public ./apps/spa/public

USER node

CMD ["node", "apps/spa/server.js"]
