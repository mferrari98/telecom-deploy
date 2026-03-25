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
  && pnpm build \
  && pnpm rebuild better-sqlite3

FROM node:20-bookworm-slim AS runner

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

WORKDIR /app

COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

# better-sqlite3 native binding is not picked up by Next.js file tracing — copy explicitly
RUN mkdir -p /app/node_modules/.pnpm/better-sqlite3@11.10.0/node_modules/better-sqlite3/build/Release
COPY --from=builder --chown=node:node \
  /app/node_modules/.pnpm/better-sqlite3@11.10.0/node_modules/better-sqlite3/build/Release/better_sqlite3.node \
  /app/node_modules/.pnpm/better-sqlite3@11.10.0/node_modules/better-sqlite3/build/Release/better_sqlite3.node

RUN mkdir -p /app/data/reportes /app/data/local && chown -R node:node /app/data

USER node

CMD ["node", "server.js"]
