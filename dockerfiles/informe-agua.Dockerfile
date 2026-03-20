FROM node:20-bookworm-slim AS builder

ARG INSECURE_TLS_BUILD=0

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/* \
  && NODE_TLS_REJECT_UNAUTHORIZED="$((1 - INSECURE_TLS_BUILD))" \
     npm install -g pnpm@9.15.3

COPY . .

RUN printf '%s\n' \
      'openssl_conf = openssl_init' '[openssl_init]' \
      'ssl_conf = ssl_sect' '[ssl_sect]' \
      'system_default = system_default_sect' '[system_default_sect]' \
      'Options = UnsafeLegacyRenegotiation' > /tmp/openssl-legacy.cnf \
  && NODE_OPTIONS="--openssl-config=/tmp/openssl-legacy.cnf --openssl-shared-config" \
     NODE_TLS_REJECT_UNAUTHORIZED="$((1 - INSECURE_TLS_BUILD))" \
     pnpm install --frozen-lockfile \
  && rm -f /tmp/openssl-legacy.cnf \
  && pnpm build

FROM node:20-alpine AS runner

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

WORKDIR /app

COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

RUN mkdir -p /app/data/reportes /app/data/local && chown -R node:node /app/data

USER node

CMD ["node", "server.js"]
