# Informe Agua Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a water analytics app (informe-agua) as a new Next.js service in the telecom-deploy ecosystem, reading reportespiolis data for dashboards, exploration, analysis, and reports.

**Architecture:** Standalone Next.js app (`basePath: '/informe-agua'`) with `better-sqlite3` for reading reportespiolis data (readonly) and a local config SQLite. Worker process runs inside the same container via `instrumentation.ts`. Shared auth via SPA session cookies (HMAC-SHA256). Deployed as a new Docker service behind nginx.

**Tech Stack:** Next.js 15 (App Router, standalone), React 18, TypeScript strict, Tailwind CSS, Recharts, better-sqlite3, pnpm, Node 20

**Spec:** `docs/superpowers/specs/2026-03-20-informe-agua-design.md`

---

## File Structure

### telecom-deploy (this repo) — modifications

```
docker-compose.yml              — add informe-agua service + nginx depends_on
docker-compose.dev.yml          — add informe-agua dev override
nginx/nginx.conf                — add /informe-agua/ routes
dockerfiles/informe-agua.Dockerfile — new multi-stage Dockerfile
setup                           — add repo clone + data dir creation
actualizar                      — add third repo check
scripts/common.sh               — add INFORME_AGUA_REPO_URL/REF defaults
.env.example                    — add WORKER_INTERVAL_MS
```

### telecom-informe-agua (new repo) — created in sources/

```
package.json
pnpm-lock.yaml
next.config.mjs
tsconfig.json
tailwind.config.js
postcss.config.js
.gitignore
.env.example

src/
  app/
    layout.tsx                    — root layout (tokens CSS, auth provider, lang=es)
    globals.css                   — Tailwind directives + HSL theme variables
    page.tsx                      — dashboard home (server component, redirects to /informe-agua/)
    explorar/
      page.tsx                    — data explorer page
    analisis/
      page.tsx                    — analysis page
    reportes/
      page.tsx                    — reports page
    config/
      page.tsx                    — settings page
    api/
      sites/
        route.ts                  — GET: list sites with latest readings
      readings/
        route.ts                  — GET: readings by site/variable/date range
      aggregations/
        route.ts                  — GET: pre-computed aggregations
      anomalies/
        route.ts                  — GET: detected anomalies
      reports/
        export/
          route.ts                — GET: generate PDF/Excel export
      dashboards/
        route.ts                  — GET/POST: saved dashboards CRUD
        [id]/
          route.ts                — PUT/DELETE: single dashboard
      alerts/
        route.ts                  — GET/POST: user alerts CRUD
        [id]/
          route.ts                — PUT/DELETE: single alert
      preferences/
        route.ts                  — GET/PUT: user preferences

  lib/
    auth.ts                       — verifyToken(), getSessionFromCookie(), middleware helper
    db/
      reportes.ts                 — better-sqlite3 readonly connection to reportespiolis DB
      config.ts                   — better-sqlite3 read-write connection to config DB
      migrations.ts               — schema version tracking + migration runner
      migrations/
        001-initial.ts            — CREATE TABLE statements for all config tables
    worker/
      index.ts                    — worker loop: setInterval, error handling, backoff
      aggregations.ts             — compute hourly/daily/weekly aggregations
      anomalies.ts                — statistical anomaly detection
    logger.ts                     — [info]/[warn]/[error] tagged console logging
    design-tokens.ts              — color, spacing, radius, shadow values from SPA

  components/
    layout/
      portal-layout.tsx           — main layout wrapper (topbar, nav, theme toggle)
      navbar.tsx                  — top nav with links to /, /reporte/, /informe-agua/
    ui/
      card.tsx                    — stat card component
      chart-wrapper.tsx           — Recharts responsive container wrapper
      data-table.tsx              — paginated table with search
      date-range-picker.tsx       — date range selector
      site-selector.tsx           — multi-select for sites
      variable-selector.tsx       — select for variable types
      status-badge.tsx            — normal/warning/critical indicator
      export-button.tsx           — PDF/Excel download trigger
    dashboard/
      overview-cards.tsx          — latest values per site
      summary-chart.tsx           — 24h overview chart
    explorer/
      explorer-filters.tsx        — filter bar (sites, variables, dates)
      explorer-chart.tsx          — interactive Recharts chart
      explorer-table.tsx          — data table view
    analysis/
      trends-chart.tsx            — moving averages visualization
      anomaly-list.tsx            — anomaly table with details
      prediction-chart.tsx        — linear projection chart
    reports/
      report-list.tsx             — list of available reports
      report-generator.tsx        — report config + generate button
    settings/
      dashboard-manager.tsx       — saved dashboards CRUD
      alert-manager.tsx           — alert thresholds CRUD
      preference-form.tsx         — UI preferences form

  middleware.ts                   — auth middleware (verify __session cookie)
  instrumentation.ts              — starts worker on server boot
```

---

## Phase 1: Infrastructure (telecom-deploy)

### Task 1: Add informe-agua defaults to scripts/common.sh

**Files:**
- Modify: `scripts/common.sh:24-28`

- [ ] **Step 1: Add repo URL and ref defaults**

In `scripts/common.sh`, after line 27 (`REPORTES_REF="${REPORTES_REF:-main}"`), add:

```bash
INFORME_AGUA_REPO_URL="${INFORME_AGUA_REPO_URL:-https://github.com/mferrari98/telecom-informe-agua.git}"
INFORME_AGUA_REF="${INFORME_AGUA_REF:-main}"
```

- [ ] **Step 2: Validate syntax**

Run: `bash -n scripts/common.sh`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add scripts/common.sh
git commit -m "feat: add informe-agua repo defaults to common.sh"
```

---

### Task 2: Update setup script for informe-agua

**Files:**
- Modify: `setup:9-11` (repo dirs), `setup:30-31` (clone calls), `setup:33-37` (data dirs), `setup:40-46` (permissions)

- [ ] **Step 1: Add INFORME_AGUA_DIR variable**

After line 10 (`REPORTES_DIR="${SOURCES_DIR}/telecom-reportespiolis"`), add:

```bash
INFORME_AGUA_DIR="${SOURCES_DIR}/telecom-informe-agua"
```

- [ ] **Step 2: Add clone_repo call**

After line 31 (`clone_repo "$REPORTES_REPO_URL" "$REPORTES_REF" "$REPORTES_DIR"`), add:

```bash
clone_repo "$INFORME_AGUA_REPO_URL" "$INFORME_AGUA_REF" "$INFORME_AGUA_DIR"
```

- [ ] **Step 3: Add data directory creation**

Change the `mkdir -p` line (currently line 37) to include the new data dir:

```bash
mkdir -p "${DATA_SPA_DIR}" "${DATA_REPORTES_DIR}" "${DATA_REPORTES_LOGS_DIR}" "${DATA_INFORME_AGUA_DIR}"
```

Add before the `mkdir -p` line:

```bash
DATA_INFORME_AGUA_DIR="${ROOT_DIR}/data/informe-agua"
```

And add `"${DATA_INFORME_AGUA_DIR}"` to the permissions `for` loop.

- [ ] **Step 4: Validate syntax**

Run: `bash -n setup`
Expected: no output (clean parse)

- [ ] **Step 5: Commit**

```bash
git add setup
git commit -m "feat: add informe-agua repo clone and data dir to setup"
```

---

### Task 3: Update actualizar script for informe-agua

**Files:**
- Modify: `actualizar:108-110`

- [ ] **Step 1: Add third repo check**

After line 110 (`check_repo "telecom-reportespiolis" ...`), add:

```bash
check_repo "telecom-informe-agua" "${SOURCES_DIR}/telecom-informe-agua" "$INFORME_AGUA_REF"
```

- [ ] **Step 2: Validate syntax**

Run: `bash -n actualizar`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add actualizar
git commit -m "feat: add informe-agua to actualizar repo checks"
```

---

### Task 4: Add WORKER_INTERVAL_MS to .env.example

**Files:**
- Modify: `.env.example`

- [ ] **Step 1: Add env var**

Append to `.env.example`:

```bash

# Informe Agua
WORKER_INTERVAL_MS=300000
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "feat: add WORKER_INTERVAL_MS to .env.example"
```

---

### Task 5: Create informe-agua Dockerfile

**Files:**
- Create: `dockerfiles/informe-agua.Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

```dockerfile
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
```

- [ ] **Step 2: Commit**

```bash
git add dockerfiles/informe-agua.Dockerfile
git commit -m "feat: add informe-agua multi-stage Dockerfile"
```

---

### Task 6: Add informe-agua routes to nginx.conf

**Files:**
- Modify: `nginx/nginx.conf:86-102` (HTTPS server block, before the `/` catch-all)

- [ ] **Step 1: Add the three location blocks**

Insert before `location = /reporte {` (line 86):

```nginx
    location ~ ^/informe-agua/_next/static/ {
      proxy_pass http://informe-agua:3000;
      proxy_http_version 1.1;
      expires 365d;
      access_log off;
      add_header Cache-Control "public, immutable";
    }

    location = /informe-agua {
      return 301 /informe-agua/;
    }

    location /informe-agua/ {
      limit_req zone=api burst=20 nodelay;
      proxy_pass http://informe-agua:3000;
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_read_timeout 120s;
    }

```

- [ ] **Step 2: Validate nginx config syntax**

Run: `docker run --rm -v "$(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" nginx:alpine nginx -t 2>&1 || true`

Expected: `nginx: the configuration file /etc/nginx/nginx.conf syntax is ok` (may warn about upstream not found — that's fine, the service doesn't exist yet)

- [ ] **Step 3: Commit**

```bash
git add nginx/nginx.conf
git commit -m "feat: add informe-agua routes to nginx config"
```

---

### Task 7: Add informe-agua service to docker-compose.yml

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add nginx depends_on for informe-agua**

In the nginx service's `depends_on` block (lines 8-12), add:

```yaml
      informe-agua:
        condition: service_healthy
```

- [ ] **Step 2: Add the informe-agua service**

After the `reportespiolis` service block (after line 126), before `volumes:`, add:

```yaml
  informe-agua:
    build:
      context: ./sources/telecom-informe-agua
      dockerfile: ../../dockerfiles/informe-agua.Dockerfile
      args:
        INSECURE_TLS_BUILD: "${INFORME_AGUA_INSECURE_TLS_BUILD:-0}"
    image: telecom-informe-agua:local
    restart: unless-stopped
    environment:
      NODE_ENV: production
      SESSION_SECRET: "${SESSION_SECRET:-change-me-to-a-random-64-char-string}"
      REPORTES_DB_PATH: /app/data/reportes/database.sqlite
      LOCAL_DB_PATH: /app/data/local/config.sqlite
      WORKER_INTERVAL_MS: "${WORKER_INTERVAL_MS:-300000}"
    volumes:
      - ./data/reportes:/app/data/reportes
      - ./data/informe-agua:/app/data/local
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    depends_on:
      reportespiolis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3000/informe-agua/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 768M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - telecom_network

```

- [ ] **Step 3: Validate compose config**

Run: `docker compose -p webtelecom config --quiet 2>&1 || true`

Note: this may warn about missing source dir — that's expected before `setup` runs.

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add informe-agua service to docker-compose"
```

---

### Task 8: Add informe-agua dev override to docker-compose.dev.yml

**Files:**
- Modify: `docker-compose.dev.yml`

- [ ] **Step 1: Add informe-agua dev service**

Append to `docker-compose.dev.yml`:

```yaml

  informe-agua:
    deploy: !reset null
    build: !reset null
    image: node:20-bookworm-slim
    user: "1000:1000"
    working_dir: /app
    command: >-
      sh -lc "([ -d node_modules/.pnpm ] || corepack pnpm install --frozen-lockfile) && corepack pnpm dev"
    environment:
      NODE_ENV: development
      HOSTNAME: 0.0.0.0
      PORT: 3000
      CHOKIDAR_USEPOLLING: "1"
      WATCHPACK_POLLING: "true"
      NEXT_TELEMETRY_DISABLED: "1"
      SESSION_SECRET: "${SESSION_SECRET:-change-me-to-a-random-64-char-string}"
      REPORTES_DB_PATH: /app/data/reportes/database.sqlite
      LOCAL_DB_PATH: /app/data/local/config.sqlite
      WORKER_INTERVAL_MS: "${WORKER_INTERVAL_MS:-300000}"
    volumes:
      - ./sources/telecom-informe-agua:/app
      - ./data/reportes:/app/data/reportes
      - ./data/informe-agua:/app/data/local
    read_only: false
    tmpfs:
      - /tmp
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3000/informe-agua/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 30s
      timeout: 5s
      retries: 10
```

- [ ] **Step 2: Commit**

```bash
git add docker-compose.dev.yml
git commit -m "feat: add informe-agua dev override to docker-compose.dev.yml"
```

---

## Phase 2: New App Scaffolding (telecom-informe-agua)

All files in this phase are created inside `sources/telecom-informe-agua/`. This directory will be the new repo.

### Task 9: Initialize Next.js project

**Files:**
- Create: `sources/telecom-informe-agua/package.json`
- Create: `sources/telecom-informe-agua/next.config.mjs`
- Create: `sources/telecom-informe-agua/tsconfig.json`
- Create: `sources/telecom-informe-agua/tailwind.config.js`
- Create: `sources/telecom-informe-agua/postcss.config.js`
- Create: `sources/telecom-informe-agua/.gitignore`
- Create: `sources/telecom-informe-agua/.env.example`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "telecom-informe-agua",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "better-sqlite3": "^11.7.0",
    "clsx": "^2.1.1",
    "date-fns": "^4.1.0",
    "lucide-react": "^0.546.0",
    "next": "15.5.10",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "recharts": "^2.15.0",
    "tailwind-merge": "^2.6.0",
    "tailwindcss-animate": "^1.0.7"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.12",
    "@types/node": "^20.0.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.17",
    "typescript": "^5.7.2"
  },
  "engines": {
    "node": ">=20.0.0"
  }
}
```

- [ ] **Step 2: Create next.config.mjs**

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  basePath: "/informe-agua",
  trailingSlash: true,
  output: "standalone",
  images: { unoptimized: true },
};

export default nextConfig;
```

- [ ] **Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 4: Create tailwind.config.js**

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        chart: {
          1: "hsl(var(--chart-1))",
          2: "hsl(var(--chart-2))",
          3: "hsl(var(--chart-3))",
          4: "hsl(var(--chart-4))",
          5: "hsl(var(--chart-5))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
```

- [ ] **Step 5: Create postcss.config.js**

```javascript
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- [ ] **Step 6: Create .gitignore**

```
node_modules/
.next/
.env
.env.local
*.tsbuildinfo
next-env.d.ts
```

- [ ] **Step 7: Create .env.example**

```bash
SESSION_SECRET=change-me-to-a-random-64-char-string
REPORTES_DB_PATH=../../../data/reportes/database.sqlite
LOCAL_DB_PATH=../../../data/informe-agua/config.sqlite
WORKER_INTERVAL_MS=300000
```

- [ ] **Step 8: Install dependencies and verify**

```bash
cd sources/telecom-informe-agua && pnpm install
```

- [ ] **Step 9: Initialize git repo and commit**

```bash
cd sources/telecom-informe-agua
git init
git add -A
git commit -m "chore: initialize Next.js project with Tailwind and better-sqlite3"
```

---

### Task 10: Design tokens and global styles

**Files:**
- Create: `src/lib/design-tokens.ts`
- Create: `src/app/globals.css`

- [ ] **Step 1: Create design-tokens.ts**

Extracted from the SPA's `@telecom/tokens` package:

```typescript
export const tokens = {
  font: {
    sans: '-apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", sans-serif',
  },
  color: {
    primary: { 500: "#3b82f6", 600: "#2563eb", 700: "#1d4ed8" },
    accent: { 500: "#22c55e", 600: "#16a34a" },
    light: {
      background: "#faf9f5",
      card: "#ffffff",
      ink900: "#141413",
      ink700: "#4d4d4b",
      ink500: "#666666",
      border: "#e2e8f0",
      borderStrong: "#cbd5e1",
      iconBg: "#f8fafc",
    },
    dark: {
      background: "#141413",
      card: "#1f1e1d",
      ink900: "#e5e4e0",
      ink700: "rgb(229 228 224 / 0.7)",
      ink500: "rgb(229 228 224 / 0.58)",
      border: "#1f1e1d",
      borderStrong: "#2a2a28",
      iconBg: "#141413",
    },
  },
  spacing: { xs: "0.25rem", sm: "0.5rem", md: "1rem", lg: "1.5rem", xl: "2rem" },
  radius: { sm: "0.5rem", md: "0.75rem", lg: "1.2rem", pill: "999px" },
  shadow: {
    card: "0 1px 2px rgb(0 0 0 / 0.08)",
    cardHover: "0 4px 10px rgb(0 0 0 / 0.14)",
  },
} as const;
```

- [ ] **Step 2: Create globals.css**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 42 29% 97%;
    --foreground: 60 3% 8%;
    --card: 0 0% 100%;
    --card-foreground: 60 3% 8%;
    --primary: 60 3% 8%;
    --primary-foreground: 60 9% 98%;
    --secondary: 210 38% 96%;
    --secondary-foreground: 60 3% 8%;
    --muted: 210 38% 96%;
    --muted-foreground: 25 5% 45%;
    --accent: 210 38% 96%;
    --accent-foreground: 60 3% 8%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 60 9% 98%;
    --border: 214 32% 91%;
    --input: 214 32% 91%;
    --ring: 60 3% 8%;
    --radius: 0.5rem;
    --chart-1: 217 91% 60%;
    --chart-2: 142 71% 45%;
    --chart-3: 47 96% 53%;
    --chart-4: 0 84% 60%;
    --chart-5: 262 83% 58%;

    --telecom-color-primary-500: #3b82f6;
    --telecom-color-primary-600: #2563eb;
    --telecom-color-accent-500: #22c55e;
    --telecom-color-bg: #faf9f5;
    --telecom-color-surface-card: #ffffff;
    --telecom-color-ink-900: #141413;
    --telecom-color-ink-700: #4d4d4b;
    --telecom-color-border: #e2e8f0;
    --telecom-shadow-card: 0 1px 2px rgb(0 0 0 / 0.08);
    --telecom-shadow-card-hover: 0 4px 10px rgb(0 0 0 / 0.14);
    --telecom-radius-sm: 0.5rem;
    --telecom-radius-md: 0.75rem;
  }

  .dark {
    --background: 30 3% 7%;
    --foreground: 42 5% 88%;
    --card: 30 3% 12%;
    --card-foreground: 42 5% 88%;
    --primary: 42 5% 88%;
    --primary-foreground: 30 3% 7%;
    --secondary: 30 5% 15%;
    --secondary-foreground: 42 5% 88%;
    --muted: 30 5% 15%;
    --muted-foreground: 42 5% 55%;
    --accent: 30 5% 15%;
    --accent-foreground: 42 5% 88%;
    --destructive: 0 62% 50%;
    --destructive-foreground: 42 5% 88%;
    --border: 30 5% 15%;
    --input: 30 5% 15%;
    --ring: 42 5% 88%;

    --telecom-color-bg: #141413;
    --telecom-color-surface-card: #1f1e1d;
    --telecom-color-ink-900: #e5e4e0;
    --telecom-color-ink-700: rgb(229 228 224 / 0.7);
    --telecom-color-border: #1f1e1d;
    --telecom-shadow-card: 0 1px 2px rgb(0 0 0 / 0.35);
    --telecom-shadow-card-hover: 0 8px 16px rgb(0 0 0 / 0.5);
  }

  * {
    border-color: hsl(var(--border));
  }

  body {
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/design-tokens.ts src/app/globals.css
git commit -m "feat: add design tokens and global styles matching SPA theme"
```

---

### Task 11: Logger and utility modules

**Files:**
- Create: `src/lib/logger.ts`
- Create: `src/lib/utils.ts`

- [ ] **Step 1: Create logger.ts**

```typescript
type LogLevel = "info" | "warn" | "error";

function log(level: LogLevel, module: string, message: string): void {
  const timestamp = new Date().toISOString();
  const line = `${timestamp} [${level}] ${module} - ${message}`;
  if (level === "error") {
    console.error(line);
  } else {
    console.log(line);
  }
}

export const logger = {
  info: (module: string, message: string) => log("info", module, message),
  warn: (module: string, message: string) => log("warn", module, message),
  error: (module: string, message: string) => log("error", module, message),
};
```

- [ ] **Step 2: Create utils.ts**

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/logger.ts src/lib/utils.ts
git commit -m "feat: add logger and cn utility"
```

---

### Task 12: Database connections

**Files:**
- Create: `src/lib/db/reportes.ts`
- Create: `src/lib/db/config.ts`
- Create: `src/lib/db/migrations.ts`
- Create: `src/lib/db/migrations/001-initial.ts`

- [ ] **Step 1: Create reportes.ts (readonly connection)**

```typescript
import Database from "better-sqlite3";
import { logger } from "@/lib/logger";

let db: Database.Database | null = null;

export function getReportesDb(): Database.Database {
  if (db) return db;

  const dbPath = process.env.REPORTES_DB_PATH;
  if (!dbPath) throw new Error("REPORTES_DB_PATH is not set");

  db = new Database(dbPath, { readonly: true });
  db.pragma("busy_timeout = 5000");
  logger.info("DB", `Connected to reportes database (readonly): ${dbPath}`);
  return db;
}

export type Sitio = {
  id: number;
  descriptor: string;
  orden: number;
  rebalse: number;
  cubicaje: number;
  maxoperativo: number | null;
};

export type TipoVariable = {
  id: number;
  descriptor: string;
  orden: number;
};

export type HistoricoLectura = {
  id: number;
  sitio_id: number;
  tipo_id: number;
  valor: number;
  etiempo: number;
};
```

- [ ] **Step 2: Create config.ts (read-write connection)**

```typescript
import Database from "better-sqlite3";
import { logger } from "@/lib/logger";
import { runMigrations } from "./migrations";

let db: Database.Database | null = null;

export function getConfigDb(): Database.Database {
  if (db) return db;

  const dbPath = process.env.LOCAL_DB_PATH;
  if (!dbPath) throw new Error("LOCAL_DB_PATH is not set");

  db = new Database(dbPath);
  db.pragma("journal_mode = WAL");
  db.pragma("busy_timeout = 5000");

  runMigrations(db);
  logger.info("DB", `Connected to config database: ${dbPath}`);
  return db;
}
```

- [ ] **Step 3: Create migrations.ts**

```typescript
import type Database from "better-sqlite3";
import { logger } from "@/lib/logger";
import { migration001 } from "./migrations/001-initial";

type Migration = {
  version: number;
  name: string;
  up: (db: Database.Database) => void;
};

const migrations: Migration[] = [migration001];

export function runMigrations(db: Database.Database): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `);

  const currentVersion = db.prepare("SELECT MAX(version) as v FROM schema_version").get() as { v: number | null };
  const current = currentVersion?.v ?? 0;

  const pending = migrations.filter((m) => m.version > current);
  if (pending.length === 0) return;

  logger.info("DB", `Running ${pending.length} migration(s)...`);

  for (const migration of pending) {
    db.transaction(() => {
      migration.up(db);
      db.prepare("INSERT INTO schema_version (version, name) VALUES (?, ?)").run(migration.version, migration.name);
    })();
    logger.info("DB", `Applied migration ${migration.version}: ${migration.name}`);
  }
}
```

- [ ] **Step 4: Create 001-initial.ts**

```typescript
import type Database from "better-sqlite3";

export const migration001 = {
  version: 1,
  name: "initial-schema",
  up(db: Database.Database) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS agregaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sitio_id INTEGER NOT NULL,
        tipo_id INTEGER NOT NULL,
        periodo TEXT NOT NULL,
        periodo_inicio INTEGER NOT NULL,
        promedio REAL,
        minimo REAL,
        maximo REAL,
        conteo INTEGER NOT NULL DEFAULT 0,
        UNIQUE(sitio_id, tipo_id, periodo, periodo_inicio)
      );

      CREATE TABLE IF NOT EXISTS anomalias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sitio_id INTEGER NOT NULL,
        tipo_id INTEGER NOT NULL,
        sitio_nombre TEXT NOT NULL,
        tipo_nombre TEXT NOT NULL,
        valor REAL NOT NULL,
        etiempo INTEGER NOT NULL,
        media REAL NOT NULL,
        desviacion REAL NOT NULL,
        detectado_el TEXT NOT NULL DEFAULT (datetime('now'))
      );

      CREATE TABLE IF NOT EXISTS dashboards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT NOT NULL,
        nombre TEXT NOT NULL,
        configuracion TEXT NOT NULL,
        creado_el TEXT NOT NULL DEFAULT (datetime('now')),
        actualizado_el TEXT NOT NULL DEFAULT (datetime('now'))
      );

      CREATE TABLE IF NOT EXISTS alertas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario TEXT NOT NULL,
        sitio_id INTEGER NOT NULL,
        tipo_id INTEGER NOT NULL,
        umbral_min REAL,
        umbral_max REAL,
        activa INTEGER NOT NULL DEFAULT 1,
        creado_el TEXT NOT NULL DEFAULT (datetime('now'))
      );

      CREATE TABLE IF NOT EXISTS preferencias (
        usuario TEXT PRIMARY KEY,
        tema TEXT NOT NULL DEFAULT 'system',
        densidad TEXT NOT NULL DEFAULT 'normal',
        actualizado_el TEXT NOT NULL DEFAULT (datetime('now'))
      );

      CREATE TABLE IF NOT EXISTS worker_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        ultimo_etiempo INTEGER NOT NULL DEFAULT 0,
        ultima_ejecucion TEXT,
        ultimo_error TEXT,
        backoff_ms INTEGER NOT NULL DEFAULT 0
      );

      INSERT OR IGNORE INTO worker_state (id, ultimo_etiempo) VALUES (1, 0);

      CREATE INDEX IF NOT EXISTS idx_agregaciones_sitio_tipo_periodo
        ON agregaciones(sitio_id, tipo_id, periodo, periodo_inicio DESC);

      CREATE INDEX IF NOT EXISTS idx_anomalias_sitio_tipo
        ON anomalias(sitio_id, tipo_id, etiempo DESC);

      CREATE INDEX IF NOT EXISTS idx_dashboards_usuario
        ON dashboards(usuario);

      CREATE INDEX IF NOT EXISTS idx_alertas_usuario
        ON alertas(usuario);
    `);
  },
};
```

- [ ] **Step 5: Verify TypeScript compiles**

Run: `cd sources/telecom-informe-agua && npx tsc --noEmit 2>&1 | head -20`

Note: may have errors about missing app files — that's expected at this stage.

- [ ] **Step 6: Commit**

```bash
git add src/lib/db/
git commit -m "feat: add database connections, migration runner, and initial schema"
```

---

### Task 13: Authentication module

**Files:**
- Create: `src/lib/auth.ts`
- Create: `src/middleware.ts`

- [ ] **Step 1: Create auth.ts**

Port of the SPA's `verifyToken()` and helpers:

```typescript
export const SESSION_COOKIE_NAME = "__session";

type TokenPayload = {
  sub: string;
  role: string;
  exp: number;
};

export type SessionInfo = {
  username: string;
  role: string;
};

let cachedSecretKey: CryptoKey | null = null;
let cachedSecretRaw: string | null = null;

async function getSecretKey(): Promise<CryptoKey> {
  const secret = process.env.SESSION_SECRET;
  if (!secret) throw new Error("SESSION_SECRET is not set");
  if (cachedSecretKey && cachedSecretRaw === secret) return cachedSecretKey;
  const enc = new TextEncoder();
  cachedSecretKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  cachedSecretRaw = secret;
  return cachedSecretKey;
}

function base64urlDecode(str: string): Uint8Array {
  const padded = str.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export async function verifyToken(token: string): Promise<TokenPayload | null> {
  try {
    const [payloadB64, sigB64] = token.split(".");
    if (!payloadB64 || !sigB64) return null;

    const key = await getSecretKey();
    const enc = new TextEncoder();
    const sigBytes = base64urlDecode(sigB64);
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes.buffer as ArrayBuffer,
      enc.encode(payloadB64)
    );
    if (!valid) return null;

    const payload = JSON.parse(
      new TextDecoder().decode(base64urlDecode(payloadB64))
    ) as TokenPayload;
    if (typeof payload.sub !== "string" || !payload.sub) return null;
    if (typeof payload.role !== "string" || !payload.role) return null;
    if (typeof payload.exp !== "number") return null;
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;

    return payload;
  } catch {
    return null;
  }
}

export async function getSessionFromRequest(
  cookieValue: string | undefined
): Promise<SessionInfo | null> {
  if (!cookieValue) return null;
  const payload = await verifyToken(cookieValue);
  if (!payload) return null;
  return { username: payload.sub, role: payload.role };
}
```

- [ ] **Step 2: Create middleware.ts**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { SESSION_COOKIE_NAME, verifyToken } from "@/lib/auth";

export async function middleware(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE_NAME)?.value;
  if (!token) {
    return NextResponse.redirect(new URL("/login/", request.url));
  }

  const payload = await verifyToken(token);
  if (!payload) {
    return NextResponse.redirect(new URL("/login/", request.url));
  }

  const headers = new Headers(request.headers);
  headers.set("x-user-name", payload.sub);
  headers.set("x-user-role", payload.role);

  return NextResponse.next({ request: { headers } });
}

// With basePath set, Next.js strips the prefix before matching.
// Match all routes except static assets.
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/auth.ts src/middleware.ts
git commit -m "feat: add auth module with shared SPA session validation"
```

---

### Task 14: Worker process

**Files:**
- Create: `src/lib/worker/index.ts`
- Create: `src/lib/worker/aggregations.ts`
- Create: `src/lib/worker/anomalies.ts`
- Create: `src/instrumentation.ts`

- [ ] **Step 1: Create worker/index.ts**

```typescript
import { logger } from "@/lib/logger";
import { getConfigDb } from "@/lib/db/config";
import { computeAggregations } from "./aggregations";
import { detectAnomalies } from "./anomalies";

const DEFAULT_INTERVAL_MS = 300_000; // 5 minutes
const MAX_BACKOFF_MS = 1_800_000; // 30 minutes

let timer: ReturnType<typeof setTimeout> | null = null;

async function runCycle(): Promise<void> {
  const configDb = getConfigDb();
  const state = configDb
    .prepare("SELECT ultimo_etiempo, backoff_ms FROM worker_state WHERE id = 1")
    .get() as { ultimo_etiempo: number; backoff_ms: number } | undefined;

  const lastEtiempo = state?.ultimo_etiempo ?? 0;

  try {
    const newLastEtiempo = computeAggregations(lastEtiempo);
    detectAnomalies(lastEtiempo);

    configDb
      .prepare(
        "UPDATE worker_state SET ultimo_etiempo = ?, ultima_ejecucion = datetime('now'), ultimo_error = NULL, backoff_ms = 0 WHERE id = 1"
      )
      .run(newLastEtiempo);

    logger.info("WORKER", `Cycle complete. Processed up to etiempo=${newLastEtiempo}`);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error("WORKER", `Cycle failed: ${message}`);

    const currentBackoff = state?.backoff_ms ?? 0;
    const newBackoff = Math.min(
      currentBackoff === 0 ? DEFAULT_INTERVAL_MS : currentBackoff * 2,
      MAX_BACKOFF_MS
    );

    configDb
      .prepare(
        "UPDATE worker_state SET ultima_ejecucion = datetime('now'), ultimo_error = ?, backoff_ms = ? WHERE id = 1"
      )
      .run(message, newBackoff);
  }
}

function scheduleNext(): void {
  const configDb = getConfigDb();
  const state = configDb
    .prepare("SELECT backoff_ms FROM worker_state WHERE id = 1")
    .get() as { backoff_ms: number } | undefined;

  const backoff = state?.backoff_ms ?? 0;
  const intervalMs = parseInt(process.env.WORKER_INTERVAL_MS ?? "", 10) || DEFAULT_INTERVAL_MS;
  const delay = backoff > 0 ? backoff : intervalMs;

  timer = setTimeout(async () => {
    await runCycle();
    scheduleNext();
  }, delay);
}

export function startWorker(): void {
  logger.info("WORKER", "Starting pre-computation worker");
  // Run first cycle immediately, then schedule
  runCycle().then(() => scheduleNext()).catch(() => scheduleNext());
}

export function stopWorker(): void {
  if (timer) {
    clearTimeout(timer);
    timer = null;
  }
}
```

- [ ] **Step 2: Create worker/aggregations.ts**

```typescript
import { getReportesDb } from "@/lib/db/reportes";
import { getConfigDb } from "@/lib/db/config";
import { logger } from "@/lib/logger";

type Reading = {
  sitio_id: number;
  tipo_id: number;
  valor: number;
  etiempo: number;
};

type PeriodConfig = {
  name: string;
  durationMs: number;
};

const PERIODS: PeriodConfig[] = [
  { name: "hourly", durationMs: 3_600_000 },
  { name: "daily", durationMs: 86_400_000 },
  { name: "weekly", durationMs: 604_800_000 },
];

export function computeAggregations(sinceEtiempo: number): number {
  const reportesDb = getReportesDb();
  const configDb = getConfigDb();

  const readings = reportesDb
    .prepare(
      "SELECT sitio_id, tipo_id, valor, etiempo FROM historico_lectura WHERE etiempo > ? ORDER BY etiempo ASC"
    )
    .all(sinceEtiempo) as Reading[];

  if (readings.length === 0) return sinceEtiempo;

  const maxEtiempo = readings[readings.length - 1].etiempo;
  logger.info("WORKER", `Processing ${readings.length} new readings`);

  const upsert = configDb.prepare(`
    INSERT INTO agregaciones (sitio_id, tipo_id, periodo, periodo_inicio, promedio, minimo, maximo, conteo)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(sitio_id, tipo_id, periodo, periodo_inicio)
    DO UPDATE SET
      promedio = (promedio * conteo + excluded.promedio * excluded.conteo) / (conteo + excluded.conteo),
      minimo = MIN(minimo, excluded.minimo),
      maximo = MAX(maximo, excluded.maximo),
      conteo = conteo + excluded.conteo
  `);

  const insertMany = configDb.transaction(() => {
    for (const period of PERIODS) {
      const buckets = new Map<string, { sum: number; min: number; max: number; count: number; start: number }>();

      for (const r of readings) {
        const periodStart = Math.floor(r.etiempo / period.durationMs) * period.durationMs;
        const key = `${r.sitio_id}:${r.tipo_id}:${periodStart}`;

        const bucket = buckets.get(key);
        if (bucket) {
          bucket.sum += r.valor;
          bucket.min = Math.min(bucket.min, r.valor);
          bucket.max = Math.max(bucket.max, r.valor);
          bucket.count++;
        } else {
          buckets.set(key, {
            sum: r.valor,
            min: r.valor,
            max: r.valor,
            count: 1,
            start: periodStart,
          });
        }
      }

      for (const [key, b] of buckets) {
        const [sitioId, tipoId] = key.split(":").map(Number);
        upsert.run(sitioId, tipoId, period.name, b.start, b.sum / b.count, b.min, b.max, b.count);
      }
    }
  });

  insertMany();
  return maxEtiempo;
}
```

- [ ] **Step 3: Create worker/anomalies.ts**

```typescript
import { getReportesDb } from "@/lib/db/reportes";
import { getConfigDb } from "@/lib/db/config";
import { logger } from "@/lib/logger";

const STDDEV_THRESHOLD = 3;
const MIN_SAMPLES = 30;

type StatsRow = {
  sitio_id: number;
  tipo_id: number;
  avg_val: number;
  stddev_val: number;
};

type Reading = {
  id: number;
  sitio_id: number;
  tipo_id: number;
  valor: number;
  etiempo: number;
};

export function detectAnomalies(sinceEtiempo: number): void {
  const reportesDb = getReportesDb();
  const configDb = getConfigDb();

  // Compute stats per site/variable from all historical data
  // Uses algebraic variance formula: stddev = sqrt(avg(x^2) - avg(x)^2) for O(n) single-pass
  const stats = reportesDb
    .prepare(`
      SELECT
        sitio_id, tipo_id,
        AVG(valor) as avg_val,
        CASE WHEN COUNT(*) >= ?
          THEN SQRT(AVG(valor * valor) - AVG(valor) * AVG(valor))
          ELSE NULL
        END as stddev_val
      FROM historico_lectura
      GROUP BY sitio_id, tipo_id
      HAVING COUNT(*) >= ?
    `)
    .all(MIN_SAMPLES, MIN_SAMPLES) as StatsRow[];

  if (stats.length === 0) return;

  const statsMap = new Map<string, { avg: number; stddev: number }>();
  for (const s of stats) {
    if (s.stddev_val !== null && s.stddev_val > 0) {
      statsMap.set(`${s.sitio_id}:${s.tipo_id}`, { avg: s.avg_val, stddev: s.stddev_val });
    }
  }

  // Build name lookup maps
  const siteNames = new Map<number, string>();
  const varNames = new Map<number, string>();
  for (const row of reportesDb.prepare("SELECT id, descriptor FROM sitio").all() as { id: number; descriptor: string }[]) {
    siteNames.set(row.id, row.descriptor);
  }
  for (const row of reportesDb.prepare("SELECT id, descriptor FROM tipo_variable").all() as { id: number; descriptor: string }[]) {
    varNames.set(row.id, row.descriptor);
  }

  // Check new readings against stats
  const newReadings = reportesDb
    .prepare("SELECT id, sitio_id, tipo_id, valor, etiempo FROM historico_lectura WHERE etiempo > ?")
    .all(sinceEtiempo) as Reading[];

  const insertAnomaly = configDb.prepare(`
    INSERT INTO anomalias (sitio_id, tipo_id, sitio_nombre, tipo_nombre, valor, etiempo, media, desviacion)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  let count = 0;
  const insertAll = configDb.transaction(() => {
    for (const r of newReadings) {
      const stat = statsMap.get(`${r.sitio_id}:${r.tipo_id}`);
      if (!stat) continue;

      const zScore = Math.abs(r.valor - stat.avg) / stat.stddev;
      if (zScore > STDDEV_THRESHOLD) {
        insertAnomaly.run(
          r.sitio_id, r.tipo_id,
          siteNames.get(r.sitio_id) ?? "Desconocido",
          varNames.get(r.tipo_id) ?? "Desconocido",
          r.valor, r.etiempo, stat.avg, stat.stddev
        );
        count++;
      }
    }
  });

  insertAll();
  if (count > 0) {
    logger.info("WORKER", `Detected ${count} anomalies`);
  }
}
```

- [ ] **Step 4: Create instrumentation.ts**

```typescript
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { startWorker } = await import("@/lib/worker");
    startWorker();
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add src/lib/worker/ src/instrumentation.ts
git commit -m "feat: add worker process for aggregations and anomaly detection"
```

---

### Task 15: Root layout and portal layout components

**Files:**
- Create: `src/app/layout.tsx`
- Create: `src/components/layout/portal-layout.tsx`
- Create: `src/components/layout/navbar.tsx`

- [ ] **Step 1: Create layout.tsx**

```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Informe Agua - Telecom",
  description: "Analytics de monitoreo de agua",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
```

- [ ] **Step 2: Create navbar.tsx**

```tsx
"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { BarChart3, Database, TrendingUp, FileText, Settings } from "lucide-react";

const NAV_ITEMS = [
  { href: "/informe-agua/", label: "Dashboard", icon: BarChart3 },
  { href: "/informe-agua/explorar/", label: "Explorar", icon: Database },
  { href: "/informe-agua/analisis/", label: "Análisis", icon: TrendingUp },
  { href: "/informe-agua/reportes/", label: "Reportes", icon: FileText },
  { href: "/informe-agua/config/", label: "Configuración", icon: Settings },
];

export function Navbar() {
  const pathname = usePathname();

  return (
    <nav className="flex items-center gap-1 overflow-x-auto px-4 py-2">
      {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
        const isActive =
          href === "/informe-agua/"
            ? pathname === "/informe-agua/"
            : pathname.startsWith(href);

        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              isActive
                ? "bg-primary text-primary-foreground"
                : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
            )}
          >
            <Icon className="h-4 w-4" />
            <span className="hidden sm:inline">{label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
```

- [ ] **Step 3: Create portal-layout.tsx**

```tsx
"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Droplets, Sun, Moon } from "lucide-react";
import { Navbar } from "./navbar";
import { cn } from "@/lib/utils";

export function PortalLayout({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<"light" | "dark">("light");

  useEffect(() => {
    const saved = localStorage.getItem("theme");
    if (saved === "dark") {
      setTheme("dark");
      document.documentElement.classList.add("dark");
    }
  }, []);

  function toggleTheme() {
    const next = theme === "light" ? "dark" : "light";
    setTheme(next);
    localStorage.setItem("theme", next);
    document.documentElement.classList.toggle("dark", next === "dark");
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="sticky top-0 z-50 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-6">
            <Link href="/" className="flex items-center gap-2 font-semibold">
              <Droplets className="h-5 w-5 text-[var(--telecom-color-primary-500)]" />
              <span>Telecom</span>
            </Link>
            <div className="hidden items-center gap-4 text-sm text-muted-foreground md:flex">
              <Link href="/" className="hover:text-foreground transition-colors">
                Portal
              </Link>
              <Link href="/reporte/" className="hover:text-foreground transition-colors">
                Reportes
              </Link>
              <span className="font-medium text-foreground">Informe Agua</span>
            </div>
          </div>
          <button
            onClick={toggleTheme}
            className="rounded-md p-2 text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors"
            aria-label="Cambiar tema"
          >
            {theme === "light" ? <Moon className="h-4 w-4" /> : <Sun className="h-4 w-4" />}
          </button>
        </div>
        <div className="mx-auto max-w-7xl border-t">
          <Navbar />
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-6">{children}</main>
    </div>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/layout.tsx src/components/layout/
git commit -m "feat: add root layout, portal layout, and navbar components"
```

---

### Task 16: API routes for data access

**Files:**
- Create: `src/app/api/sites/route.ts`
- Create: `src/app/api/readings/route.ts`
- Create: `src/app/api/aggregations/route.ts`
- Create: `src/app/api/anomalies/route.ts`

- [ ] **Step 1: Create sites API route**

```typescript
import { NextResponse } from "next/server";
import { getReportesDb } from "@/lib/db/reportes";

export function GET() {
  const db = getReportesDb();

  const sites = db
    .prepare("SELECT id, descriptor, orden, rebalse, cubicaje, maxoperativo FROM sitio ORDER BY orden")
    .all();

  // Get latest reading per site per variable
  const latest = db
    .prepare(`
      SELECT h.sitio_id, h.tipo_id, h.valor, h.etiempo, tv.descriptor as tipo_descriptor
      FROM historico_lectura h
      INNER JOIN tipo_variable tv ON tv.id = h.tipo_id
      WHERE h.etiempo = (
        SELECT MAX(h2.etiempo) FROM historico_lectura h2
        WHERE h2.sitio_id = h.sitio_id AND h2.tipo_id = h.tipo_id
      )
      ORDER BY h.sitio_id, tv.orden
    `)
    .all();

  return NextResponse.json({ sites, latest });
}
```

- [ ] **Step 2: Create readings API route**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { getReportesDb } from "@/lib/db/reportes";

export function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const siteIds = searchParams.get("sites")?.split(",").map(Number).filter(Boolean) ?? [];
  const tipoId = Number(searchParams.get("tipo")) || null;
  const desde = Number(searchParams.get("desde")) || 0;
  const hasta = Number(searchParams.get("hasta")) || Date.now();
  const limit = Math.min(Number(searchParams.get("limit")) || 5000, 10000);
  const offset = Number(searchParams.get("offset")) || 0;

  if (siteIds.length === 0) {
    return NextResponse.json({ error: "sites parameter required" }, { status: 400 });
  }

  const db = getReportesDb();
  const placeholders = siteIds.map(() => "?").join(",");

  let query = `
    SELECT h.sitio_id, h.tipo_id, h.valor, h.etiempo, s.descriptor as sitio_nombre, tv.descriptor as tipo_nombre
    FROM historico_lectura h
    INNER JOIN sitio s ON s.id = h.sitio_id
    INNER JOIN tipo_variable tv ON tv.id = h.tipo_id
    WHERE h.sitio_id IN (${placeholders})
    AND h.etiempo BETWEEN ? AND ?
  `;
  const params: (number | null)[] = [...siteIds, desde, hasta];

  if (tipoId) {
    query += " AND h.tipo_id = ?";
    params.push(tipoId);
  }

  query += " ORDER BY h.etiempo DESC LIMIT ? OFFSET ?";
  params.push(limit, offset);

  const readings = db.prepare(query).all(...params);
  const total = db
    .prepare(
      `SELECT COUNT(*) as count FROM historico_lectura
       WHERE sitio_id IN (${placeholders}) AND etiempo BETWEEN ? AND ?${tipoId ? " AND tipo_id = ?" : ""}`
    )
    .get(...(tipoId ? [...siteIds, desde, hasta, tipoId] : [...siteIds, desde, hasta])) as { count: number };

  return NextResponse.json({ readings, total: total.count, limit, offset });
}
```

- [ ] **Step 3: Create aggregations API route**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { getConfigDb } from "@/lib/db/config";

export function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const siteIds = searchParams.get("sites")?.split(",").map(Number).filter(Boolean) ?? [];
  const tipoId = Number(searchParams.get("tipo")) || null;
  const periodo = searchParams.get("periodo") || "daily";
  const desde = Number(searchParams.get("desde")) || 0;
  const hasta = Number(searchParams.get("hasta")) || Date.now();

  if (siteIds.length === 0) {
    return NextResponse.json({ error: "sites parameter required" }, { status: 400 });
  }

  const db = getConfigDb();
  const placeholders = siteIds.map(() => "?").join(",");

  let query = `
    SELECT sitio_id, tipo_id, periodo, periodo_inicio, promedio, minimo, maximo, conteo
    FROM agregaciones
    WHERE sitio_id IN (${placeholders})
    AND periodo = ?
    AND periodo_inicio BETWEEN ? AND ?
  `;
  const params: (string | number)[] = [...siteIds, periodo, desde, hasta];

  if (tipoId) {
    query += " AND tipo_id = ?";
    params.push(tipoId);
  }

  query += " ORDER BY periodo_inicio DESC";

  const aggregations = db.prepare(query).all(...params);

  return NextResponse.json({ aggregations });
}
```

- [ ] **Step 4: Create anomalies API route**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { getConfigDb } from "@/lib/db/config";

export function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const siteIds = searchParams.get("sites")?.split(",").map(Number).filter(Boolean) ?? [];
  const limit = Math.min(Number(searchParams.get("limit")) || 100, 500);

  const db = getConfigDb();

  let query: string;
  let params: number[];

  if (siteIds.length > 0) {
    const placeholders = siteIds.map(() => "?").join(",");
    query = `
      SELECT * FROM anomalias
      WHERE sitio_id IN (${placeholders})
      ORDER BY etiempo DESC LIMIT ?
    `;
    params = [...siteIds, limit];
  } else {
    query = `SELECT * FROM anomalias ORDER BY etiempo DESC LIMIT ?`;
    params = [limit];
  }

  const anomalies = db.prepare(query).all(...params);

  return NextResponse.json({ anomalies });
}

- [ ] **Step 5: Commit**

```bash
git add src/app/api/
git commit -m "feat: add API routes for sites, readings, aggregations, and anomalies"
```

---

### Task 17: Shared UI components

**Files:**
- Create: `src/components/ui/card.tsx`
- Create: `src/components/ui/chart-wrapper.tsx`
- Create: `src/components/ui/status-badge.tsx`
- Create: `src/components/ui/data-table.tsx`
- Create: `src/components/ui/date-range-picker.tsx`
- Create: `src/components/ui/site-selector.tsx`

- [ ] **Step 1: Create card.tsx**

```tsx
import { cn } from "@/lib/utils";

type CardProps = {
  title?: string;
  className?: string;
  children: React.ReactNode;
};

export function Card({ title, className, children }: CardProps) {
  return (
    <article
      className={cn(
        "rounded-[var(--telecom-radius-md)] bg-card p-4 shadow-[var(--telecom-shadow-card)] transition-shadow hover:shadow-[var(--telecom-shadow-card-hover)]",
        className
      )}
    >
      {title && <h3 className="mb-3 text-sm font-semibold text-muted-foreground">{title}</h3>}
      {children}
    </article>
  );
}
```

- [ ] **Step 2: Create chart-wrapper.tsx**

```tsx
"use client";

import { ResponsiveContainer } from "recharts";

type ChartWrapperProps = {
  height?: number;
  children: React.ReactNode;
};

export function ChartWrapper({ height = 300, children }: ChartWrapperProps) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      {children as React.ReactElement}
    </ResponsiveContainer>
  );
}
```

- [ ] **Step 3: Create status-badge.tsx**

```tsx
import { cn } from "@/lib/utils";

type Status = "normal" | "warning" | "critical";

type StatusBadgeProps = {
  status: Status;
  label?: string;
};

const STATUS_STYLES: Record<Status, string> = {
  normal: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400",
  warning: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400",
  critical: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
};

const STATUS_LABELS: Record<Status, string> = {
  normal: "Normal",
  warning: "Alerta",
  critical: "Crítico",
};

export function StatusBadge({ status, label }: StatusBadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        STATUS_STYLES[status]
      )}
    >
      {label ?? STATUS_LABELS[status]}
    </span>
  );
}
```

- [ ] **Step 4: Create data-table.tsx**

```tsx
"use client";

import { useState, useMemo } from "react";

type Column<T> = {
  key: keyof T;
  label: string;
  render?: (value: T[keyof T], row: T) => React.ReactNode;
};

type DataTableProps<T> = {
  data: T[];
  columns: Column<T>[];
  pageSize?: number;
  searchable?: boolean;
  searchKeys?: (keyof T)[];
};

export function DataTable<T extends Record<string, unknown>>({
  data,
  columns,
  pageSize = 20,
  searchable = false,
  searchKeys = [],
}: DataTableProps<T>) {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");

  const filtered = useMemo(() => {
    if (!search || searchKeys.length === 0) return data;
    const lower = search.toLowerCase();
    return data.filter((row) =>
      searchKeys.some((key) => String(row[key]).toLowerCase().includes(lower))
    );
  }, [data, search, searchKeys]);

  const totalPages = Math.ceil(filtered.length / pageSize);
  const pageData = filtered.slice(page * pageSize, (page + 1) * pageSize);

  return (
    <div>
      {searchable && (
        <input
          type="text"
          placeholder="Buscar..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(0);
          }}
          className="mb-4 w-full rounded-md border bg-background px-3 py-2 text-sm"
        />
      )}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b">
              {columns.map((col) => (
                <th key={String(col.key)} className="px-3 py-2 text-left font-medium text-muted-foreground">
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {pageData.map((row, i) => (
              <tr key={i} className="border-b last:border-0">
                {columns.map((col) => (
                  <td key={String(col.key)} className="px-3 py-2">
                    {col.render ? col.render(row[col.key], row) : String(row[col.key] ?? "")}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-muted-foreground">
          <span>
            {filtered.length} resultado{filtered.length !== 1 ? "s" : ""}
          </span>
          <div className="flex gap-2">
            <button
              onClick={() => setPage(Math.max(0, page - 1))}
              disabled={page === 0}
              className="rounded px-2 py-1 hover:bg-accent disabled:opacity-50"
            >
              Anterior
            </button>
            <span>
              {page + 1} / {totalPages}
            </span>
            <button
              onClick={() => setPage(Math.min(totalPages - 1, page + 1))}
              disabled={page >= totalPages - 1}
              className="rounded px-2 py-1 hover:bg-accent disabled:opacity-50"
            >
              Siguiente
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 5: Create date-range-picker.tsx and site-selector.tsx**

`date-range-picker.tsx`:
```tsx
"use client";

import { format } from "date-fns";

type DateRangePickerProps = {
  desde: Date;
  hasta: Date;
  onChange: (desde: Date, hasta: Date) => void;
};

export function DateRangePicker({ desde, hasta, onChange }: DateRangePickerProps) {
  return (
    <div className="flex items-center gap-2">
      <label className="text-sm text-muted-foreground">Desde</label>
      <input
        type="date"
        value={format(desde, "yyyy-MM-dd")}
        onChange={(e) => onChange(new Date(e.target.value), hasta)}
        className="rounded-md border bg-background px-2 py-1 text-sm"
      />
      <label className="text-sm text-muted-foreground">Hasta</label>
      <input
        type="date"
        value={format(hasta, "yyyy-MM-dd")}
        onChange={(e) => onChange(desde, new Date(e.target.value))}
        className="rounded-md border bg-background px-2 py-1 text-sm"
      />
    </div>
  );
}
```

`variable-selector.tsx`:
```tsx
"use client";

type Variable = {
  id: number;
  descriptor: string;
};

type VariableSelectorProps = {
  variables: Variable[];
  selected: number | null;
  onChange: (id: number | null) => void;
};

export function VariableSelector({ variables, selected, onChange }: VariableSelectorProps) {
  return (
    <select
      value={selected ?? ""}
      onChange={(e) => onChange(e.target.value ? Number(e.target.value) : null)}
      className="rounded-md border bg-background px-3 py-1.5 text-sm"
    >
      <option value="">Todas las variables</option>
      {variables.map((v) => (
        <option key={v.id} value={v.id}>
          {v.descriptor}
        </option>
      ))}
    </select>
  );
}
```

`site-selector.tsx`:
```tsx
"use client";

type Site = {
  id: number;
  descriptor: string;
};

type SiteSelectorProps = {
  sites: Site[];
  selected: number[];
  onChange: (ids: number[]) => void;
};

export function SiteSelector({ sites, selected, onChange }: SiteSelectorProps) {
  function toggle(id: number) {
    if (selected.includes(id)) {
      onChange(selected.filter((s) => s !== id));
    } else {
      onChange([...selected, id]);
    }
  }

  return (
    <div className="flex flex-wrap gap-2">
      {sites.map((site) => (
        <button
          key={site.id}
          onClick={() => toggle(site.id)}
          className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
            selected.includes(site.id)
              ? "bg-primary text-primary-foreground"
              : "bg-secondary text-secondary-foreground hover:bg-accent"
          }`}
        >
          {site.descriptor}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 6: Commit**

```bash
git add src/components/ui/
git commit -m "feat: add shared UI components (card, chart, table, selectors, badges)"
```

---

### Task 18: Dashboard page

**Files:**
- Create: `src/app/page.tsx`
- Create: `src/components/dashboard/overview-cards.tsx`
- Create: `src/components/dashboard/summary-chart.tsx`

- [ ] **Step 1: Create overview-cards.tsx**

```tsx
"use client";

import { Card } from "@/components/ui/card";
import { StatusBadge } from "@/components/ui/status-badge";

type LatestReading = {
  sitio_id: number;
  tipo_id: number;
  valor: number;
  etiempo: number;
  tipo_descriptor: string;
};

type Site = {
  id: number;
  descriptor: string;
  rebalse: number;
  maxoperativo: number | null;
};

type OverviewCardsProps = {
  sites: Site[];
  latest: LatestReading[];
};

function getStatus(value: number, rebalse: number, maxoperativo: number | null): "normal" | "warning" | "critical" {
  if (value >= rebalse) return "critical";
  if (maxoperativo && value >= maxoperativo * 0.9) return "warning";
  return "normal";
}

export function OverviewCards({ sites, latest }: OverviewCardsProps) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {sites.map((site) => {
        const readings = latest.filter((r) => r.sitio_id === site.id);
        const nivelReading = readings.find((r) => r.tipo_descriptor.startsWith("Nivel"));
        const status = nivelReading
          ? getStatus(nivelReading.valor, site.rebalse, site.maxoperativo)
          : "normal";

        return (
          <Card key={site.id} className="relative">
            <div className="flex items-start justify-between">
              <h3 className="font-semibold">{site.descriptor}</h3>
              <StatusBadge status={status} />
            </div>
            <div className="mt-3 space-y-1">
              {readings.map((r) => (
                <div key={r.tipo_id} className="flex justify-between text-sm">
                  <span className="text-muted-foreground">{r.tipo_descriptor}</span>
                  <span className="font-mono">{r.valor.toFixed(2)}</span>
                </div>
              ))}
            </div>
            {nivelReading && (
              <p className="mt-2 text-xs text-muted-foreground">
                Actualizado: {new Date(nivelReading.etiempo).toLocaleString("es-AR")}
              </p>
            )}
          </Card>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 2: Create summary-chart.tsx**

```tsx
"use client";

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from "recharts";
import { ChartWrapper } from "@/components/ui/chart-wrapper";

type ChartDataPoint = {
  etiempo: number;
  [siteName: string]: number;
};

type SummaryChartProps = {
  data: ChartDataPoint[];
  siteNames: string[];
};

const COLORS = ["#3b82f6", "#22c55e", "#eab308", "#ef4444", "#8b5cf6", "#06b6d4", "#f97316", "#ec4899"];

export function SummaryChart({ data, siteNames }: SummaryChartProps) {
  return (
    <ChartWrapper height={350}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
        <XAxis
          dataKey="etiempo"
          tickFormatter={(v) => new Date(v).toLocaleTimeString("es-AR", { hour: "2-digit", minute: "2-digit" })}
          stroke="hsl(var(--muted-foreground))"
          fontSize={12}
        />
        <YAxis stroke="hsl(var(--muted-foreground))" fontSize={12} />
        <Tooltip
          labelFormatter={(v) => new Date(v as number).toLocaleString("es-AR")}
          contentStyle={{
            backgroundColor: "hsl(var(--card))",
            border: "1px solid hsl(var(--border))",
            borderRadius: "var(--telecom-radius-sm)",
          }}
        />
        <Legend />
        {siteNames.map((name, i) => (
          <Line
            key={name}
            type="monotone"
            dataKey={name}
            stroke={COLORS[i % COLORS.length]}
            strokeWidth={2}
            dot={false}
          />
        ))}
      </LineChart>
    </ChartWrapper>
  );
}
```

- [ ] **Step 3: Create dashboard page.tsx**

```tsx
import { getReportesDb } from "@/lib/db/reportes";
import { PortalLayout } from "@/components/layout/portal-layout";
import { OverviewCards } from "@/components/dashboard/overview-cards";
import { SummaryChart } from "@/components/dashboard/summary-chart";
import { Card } from "@/components/ui/card";

export default function DashboardPage() {
  const db = getReportesDb();

  const sites = db
    .prepare("SELECT id, descriptor, orden, rebalse, cubicaje, maxoperativo FROM sitio ORDER BY orden")
    .all() as { id: number; descriptor: string; orden: number; rebalse: number; cubicaje: number; maxoperativo: number | null }[];

  const latest = db
    .prepare(`
      SELECT h.sitio_id, h.tipo_id, h.valor, h.etiempo, tv.descriptor as tipo_descriptor
      FROM historico_lectura h
      INNER JOIN tipo_variable tv ON tv.id = h.tipo_id
      WHERE h.etiempo = (
        SELECT MAX(h2.etiempo) FROM historico_lectura h2
        WHERE h2.sitio_id = h.sitio_id AND h2.tipo_id = h.tipo_id
      )
      ORDER BY h.sitio_id, tv.orden
    `)
    .all() as { sitio_id: number; tipo_id: number; valor: number; etiempo: number; tipo_descriptor: string }[];

  // Last 24h data for level readings — for the summary chart
  const oneDayAgo = Date.now() - 86_400_000;
  const nivelTipo = db.prepare("SELECT id FROM tipo_variable WHERE descriptor LIKE 'Nivel%'").get() as { id: number } | undefined;

  let chartData: { etiempo: number; [key: string]: number }[] = [];
  let chartSiteNames: string[] = [];

  if (nivelTipo) {
    const readings = db
      .prepare(`
        SELECT h.sitio_id, s.descriptor as sitio_nombre, h.valor, h.etiempo
        FROM historico_lectura h
        INNER JOIN sitio s ON s.id = h.sitio_id
        WHERE h.tipo_id = ? AND h.etiempo > ?
        ORDER BY h.etiempo ASC
      `)
      .all(nivelTipo.id, oneDayAgo) as { sitio_id: number; sitio_nombre: string; valor: number; etiempo: number }[];

    chartSiteNames = [...new Set(readings.map((r) => r.sitio_nombre))];

    const byTime = new Map<number, Record<string, number>>();
    for (const r of readings) {
      const bucket = Math.floor(r.etiempo / 3_600_000) * 3_600_000;
      if (!byTime.has(bucket)) {
        byTime.set(bucket, { etiempo: bucket });
      }
      byTime.get(bucket)![r.sitio_nombre] = r.valor;
    }
    chartData = Array.from(byTime.values()).sort((a, b) => a.etiempo - b.etiempo);
  }

  return (
    <PortalLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Dashboard</h1>
          <p className="text-muted-foreground">Monitoreo de agua en tiempo real</p>
        </div>

        <OverviewCards sites={sites} latest={latest} />

        {chartData.length > 0 && (
          <Card title="Niveles — Últimas 24 horas">
            <SummaryChart data={chartData} siteNames={chartSiteNames} />
          </Card>
        )}
      </div>
    </PortalLayout>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/page.tsx src/components/dashboard/
git commit -m "feat: add dashboard page with overview cards and summary chart"
```

---

### Task 19: Data Explorer page

**Files:**
- Create: `src/components/explorer/explorer-filters.tsx`
- Create: `src/components/explorer/explorer-chart.tsx`
- Create: `src/components/explorer/explorer-table.tsx`
- Create: `src/app/explorar/page.tsx`

This is a client-side page that fetches data from API routes. Implementation follows the same patterns established in Tasks 17-18: filter bar at top, Recharts chart below, data table at bottom. API calls go to `/informe-agua/api/readings/` with query params.

- [ ] **Step 1: Create explorer-filters.tsx**

A horizontal filter bar with `SiteSelector`, a variable type dropdown, `DateRangePicker`, and a "Buscar" button that triggers the parent's fetch.

- [ ] **Step 2: Create explorer-chart.tsx**

A Recharts `LineChart` that renders multiple lines (one per selected site), using the chart colors and tooltip styling from `summary-chart.tsx`.

- [ ] **Step 3: Create explorer-table.tsx**

Uses `DataTable` component with columns: Sitio, Variable, Valor, Fecha. Searchable by site name.

- [ ] **Step 4: Create explorar/page.tsx**

Client component that manages state (selected sites, variable, date range), fetches from `/informe-agua/api/readings/`, and renders `ExplorerFilters`, `ExplorerChart`, and `ExplorerTable` inside `PortalLayout`.

- [ ] **Step 5: Commit**

```bash
git add src/components/explorer/ src/app/explorar/
git commit -m "feat: add data explorer page with filters, chart, and table"
```

---

### Task 20: Analysis page

**Files:**
- Create: `src/components/analysis/trends-chart.tsx`
- Create: `src/components/analysis/anomaly-list.tsx`
- Create: `src/components/analysis/prediction-chart.tsx`
- Create: `src/app/analisis/page.tsx`

- [ ] **Step 1: Create trends-chart.tsx**

Recharts chart that plots aggregation data (daily averages) with min/max as area bands using `Area` + `Line` from Recharts. Fetches from `/informe-agua/api/aggregations/`.

- [ ] **Step 2: Create anomaly-list.tsx**

Uses `DataTable` to display anomalies with columns: Sitio, Variable, Valor, Media, Desviación, Fecha. Status badge shows severity.

- [ ] **Step 3: Create prediction-chart.tsx**

Takes daily aggregation data and computes a simple linear regression (least squares). Renders the actual data as a solid line and the projection as a dashed line using Recharts.

- [ ] **Step 4: Create analisis/page.tsx**

Client component with site/variable selectors, tabs for Trends | Anomalies | Predictions. Fetches from aggregations and anomalies API routes.

- [ ] **Step 5: Commit**

```bash
git add src/components/analysis/ src/app/analisis/
git commit -m "feat: add analysis page with trends, anomalies, and predictions"
```

---

### Task 21: Reports page

**Files:**
- Create: `src/app/api/reports/export/route.ts`
- Create: `src/components/reports/report-list.tsx`
- Create: `src/components/reports/report-generator.tsx`
- Create: `src/app/reportes/page.tsx`

- [ ] **Step 1: Create export API route**

API route that generates PDF (using React-rendered HTML converted via a lightweight library like `jspdf` + `html2canvas`, or server-rendered HTML) and Excel (using `exceljs` library — add to package.json dependencies).

Add `exceljs` to `package.json`:
```bash
cd sources/telecom-informe-agua && pnpm add exceljs
```

The route accepts query params: `format=pdf|xlsx`, `sites`, `tipo`, `periodo`, `desde`, `hasta`. Returns the file as a download.

- [ ] **Step 2: Create report-list.tsx and report-generator.tsx**

`report-list.tsx`: list of predefined report templates (daily, weekly, monthly) with download buttons.
`report-generator.tsx`: form to configure custom report parameters (sites, variables, date range, format).

- [ ] **Step 3: Create reportes/page.tsx**

Page with two sections: predefined reports grid and custom report generator form, inside `PortalLayout`.

- [ ] **Step 4: Commit**

```bash
git add src/app/api/reports/ src/components/reports/ src/app/reportes/
git commit -m "feat: add reports page with PDF/Excel export"
```

---

### Task 22: Settings page (dashboards, alerts, preferences)

**Files:**
- Create: `src/app/api/dashboards/route.ts`
- Create: `src/app/api/dashboards/[id]/route.ts`
- Create: `src/app/api/alerts/route.ts`
- Create: `src/app/api/alerts/[id]/route.ts`
- Create: `src/app/api/preferences/route.ts`
- Create: `src/components/settings/dashboard-manager.tsx`
- Create: `src/components/settings/alert-manager.tsx`
- Create: `src/components/settings/preference-form.tsx`
- Create: `src/app/config/page.tsx`

- [ ] **Step 1: Create CRUD API routes**

Standard REST endpoints for dashboards, alerts, and preferences. All extract username from `x-user-name` header (set by middleware). Use `getConfigDb()` for all operations.

- [ ] **Step 2: Create settings components**

`dashboard-manager.tsx`: list saved dashboards, create/edit/delete with name + JSON config.
`alert-manager.tsx`: list alerts, create/edit/delete with site/variable/threshold fields.
`preference-form.tsx`: theme selector (light/dark/system), data density (compact/normal), save button.

- [ ] **Step 3: Create config/page.tsx**

Tabbed layout (Dashboards | Alertas | Preferencias) inside `PortalLayout`, renders the three manager components.

- [ ] **Step 4: Commit**

```bash
git add src/app/api/dashboards/ src/app/api/alerts/ src/app/api/preferences/ src/components/settings/ src/app/config/
git commit -m "feat: add settings page with dashboard, alert, and preference management"
```

---

## Phase 3: Integration and Verification

### Task 23: Build verification and type checking

- [ ] **Step 1: Run typecheck**

```bash
cd sources/telecom-informe-agua && pnpm typecheck
```

Fix any TypeScript errors.

- [ ] **Step 2: Run build**

```bash
cd sources/telecom-informe-agua && pnpm build
```

Verify standalone output is generated at `.next/standalone/`.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix: resolve build and type errors"
```

---

### Task 24: Docker build and compose validation

- [ ] **Step 1: Validate compose config**

```bash
docker compose -p webtelecom config --quiet
```

- [ ] **Step 2: Build informe-agua image**

```bash
docker compose -p webtelecom build informe-agua
```

- [ ] **Step 3: Validate nginx config with all upstreams**

```bash
docker compose -p webtelecom up -d nginx
docker compose -p webtelecom logs nginx | head -20
```

- [ ] **Step 4: Commit any fixes**

---

### Task 25: End-to-end smoke test

- [ ] **Step 1: Start full stack**

```bash
docker compose -p webtelecom up -d --build --remove-orphans
```

- [ ] **Step 2: Verify healthchecks**

```bash
docker compose -p webtelecom ps
```

All services should be "healthy".

- [ ] **Step 3: Test informe-agua routes**

```bash
curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/informe-agua/       # expect 302 (redirect to login) or 200
curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/informe-agua         # expect 301 (redirect to trailing slash)
```

- [ ] **Step 4: Test with authenticated session**

Log in via the SPA, grab the `__session` cookie, and test:

```bash
curl -k -sS -b "__session=<token>" -o /dev/null -w "%{http_code}\n" https://localhost/informe-agua/
curl -k -sS -b "__session=<token>" https://localhost/informe-agua/api/sites/ | head -50
```

- [ ] **Step 5: Commit telecom-deploy changes**

```bash
git add -A && git commit -m "feat: integrate informe-agua into telecom-deploy ecosystem"
```
