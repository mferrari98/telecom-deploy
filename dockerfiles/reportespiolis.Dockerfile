FROM node:20-slim

WORKDIR /app

RUN set -eux; \
    success=0; \
    for attempt in 1 2 3 4 5; do \
      rm -rf /var/lib/apt/lists/*; \
      if apt-get update -o Acquire::Retries=5 && apt-get install -y --no-install-recommends --fix-missing \
        ca-certificates \
        python3 \
        make \
        g++ \
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

COPY package.json package-lock.json ./
RUN npm ci

COPY config.json ./
COPY sitios.json ./
COPY index.js ./
COPY src ./src

CMD ["npm", "start"]
