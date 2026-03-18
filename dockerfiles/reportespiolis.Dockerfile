FROM node:20-slim AS builder

ARG INSECURE_TLS_BUILD=0

WORKDIR /app

RUN set -eux; \
    success=0; \
    for attempt in 1 2 3 4 5; do \
      rm -rf /var/lib/apt/lists/*; \
      if apt-get update -o Acquire::Retries=5 && apt-get install -y --no-install-recommends --fix-missing \
        python3 \
        make \
        g++; then \
        success=1; \
        break; \
      fi; \
      apt-get -y --fix-broken install || true; \
      echo "apt install failed on attempt ${attempt}, retrying..."; \
      sleep 5; \
    done; \
    if [ "${success}" -ne 1 ]; then \
      echo "apt install failed after retries"; \
      exit 1; \
    fi; \
    rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN NODE_TLS_REJECT_UNAUTHORIZED="$((1 - INSECURE_TLS_BUILD))" npm ci

# ---

FROM node:20-slim AS runner

WORKDIR /app

RUN set -eux; \
    success=0; \
    for attempt in 1 2 3 4 5; do \
      rm -rf /var/lib/apt/lists/*; \
      if apt-get update -o Acquire::Retries=5 && apt-get install -y --no-install-recommends --fix-missing \
        ca-certificates \
        wget \
        fonts-liberation \
        libnss3 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libxkbcommon0 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libgbm1 \
        libxss1 \
        libasound2 \
        libcups2 \
        libgtk-3-0 \
        libgconf-2-4 \
        libxfixes3 \
        libatk1.0-0 \
        libcairo-gobject2 \
        libpango-1.0-0 \
        libgdk-pixbuf2.0-0 \
        libxcursor1 \
        libxi6 \
        libxtst6 \
        libpangocairo-1.0-0; then \
        success=1; \
        break; \
      fi; \
      echo "apt install failed on attempt ${attempt}, retrying..."; \
      sleep 5; \
    done; \
    if [ "${success}" -ne 1 ]; then \
      echo "apt install failed after retries"; \
      exit 1; \
    fi; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /root/.cache/puppeteer /home/node/.cache/puppeteer
COPY package.json ./
COPY config.json ./
COPY sitios.json ./
COPY index.js ./
COPY src ./src

RUN mkdir -p /app/logs /app/data \
 && chown -R node:node /app

USER node

CMD ["npm", "start"]
