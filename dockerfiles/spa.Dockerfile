FROM node:20-bookworm-slim AS base

RUN corepack enable

WORKDIR /app

FROM base AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY . .

ARG INSECURE_TLS_BUILD=0
RUN printf '%s\n' \
      'openssl_conf = openssl_init' \
      '[openssl_init]' \
      'ssl_conf = ssl_sect' \
      '[ssl_sect]' \
      'system_default = system_default_sect' \
      '[system_default_sect]' \
      'Options = UnsafeLegacyRenegotiation' \
      > /tmp/openssl-legacy.cnf \
  && NODE_OPTIONS="--openssl-config=/tmp/openssl-legacy.cnf --openssl-shared-config" \
     NODE_TLS_REJECT_UNAUTHORIZED="$((1 - INSECURE_TLS_BUILD))" \
     pnpm install --frozen-lockfile \
  && rm -f /tmp/openssl-legacy.cnf
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
