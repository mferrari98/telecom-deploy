# Informe Agua — Design Spec

**Date:** 2026-03-20
**Status:** Draft
**Author:** Claude + mferrari

## Overview

New analytics application for the telecom water monitoring platform. Reads the existing reportespiolis SQLite database to provide dashboards, data exploration, advanced analysis (anomaly detection, trend prediction), and exportable reports. Lives as its own repo and Docker service within the telecom-deploy ecosystem.

## Goals

- Exploit historical water monitoring data (levels, chlorine, turbidity, daily volume) across 14+ sites
- Provide interactive dashboards, data exploration, and exportable reports (PDF/Excel)
- Detect anomalies and project short-term trends
- Feel like part of the same web application (shared design system, shared auth)
- Minimize operational complexity (single container, familiar stack)

## Architecture

```
Client (HTTPS)
    ↓
Nginx:443
    ├─→ /                  → spa:3000
    ├─→ /reporte/          → reportespiolis:3000
    └─→ /informe-agua/     → informe-agua:3000  ← NEW

informe-agua (Next.js):
    ├─ Reads: data/reportes/database.sqlite (read-only, shared volume)
    ├─ Writes: data/informe-agua/config.sqlite (dashboards, alerts, prefs)
    ├─ Worker: internal pre-computation process (aggregations, anomaly detection)
    └─ Auth: validates SPA session cookies (same SESSION_SECRET)
```

**Repo:** `telecom-informe-agua` (github.com/mferrari98/telecom-informe-agua)

**Stack:** Next.js (standalone, `basePath: '/informe-agua'`), Node 20, pnpm, Recharts, SQLite (better-sqlite3)

## Data Sources

### Reportespiolis database (read-only)

Source: `data/reportes/database.sqlite` (~10MB, growing)

| Table | Purpose |
|-------|---------|
| `sitio` | Water sites: id, descriptor, orden, rebalse, cubicaje, maxoperativo |
| `tipo_variable` | Metric types: Nivel[m], Cloro[mlg/l], Turbiedad[UTN], VOL/DIA[m3/dia] |
| `historico_lectura` | Time-series: sitio_id, tipo_id, valor (REAL), etiempo (BIGINT ms) |
| `log` | System audit log |

Indexes: `(sitio_id, tipo_id)` and `(etiempo DESC)` on `historico_lectura`.

**SQLite concurrency:** reportespiolis uses `node-sqlite3` with default rollback journal mode (not WAL). With rollback journal, readers see the last committed state and do not require `-wal`/`-shm` files. The volume is mounted read-write (not `:ro`) but `better-sqlite3` opens the connection with `readonly: true` to prevent accidental writes. A `busy_timeout` of 5000ms is configured to handle brief lock contention during reportespiolis writes.

### Local config database (read-write)

Source: `data/informe-agua/config.sqlite`

| Table | Purpose |
|-------|---------|
| `agregaciones` | Pre-computed averages, min, max by site/variable/period |
| `anomalias` | Readings detected as out of statistical range |
| `dashboards` | Saved dashboard configurations per user |
| `alertas` | Custom thresholds per user/site/variable |
| `preferencias` | UI preferences per user |
| `worker_state` | Last processed etiempo, worker status |
| `schema_version` | Current schema version for migration tracking |

**Schema management:** tables are created on first startup via `CREATE TABLE IF NOT EXISTS`. A `schema_version` table tracks the current version number. On startup, a simple migration runner applies any pending migrations sequentially.

## Pages and Features

### Dashboard (`/informe-agua/`)

- Overview cards: latest value per site (level, chlorine, turbidity, volume)
- Status indicators: normal / warning / critical based on `sitios.json` thresholds
- Summary chart: last 24h across all sites

### Data Explorer (`/informe-agua/explorar`)

- Multi-select: site(s) + variable type + date range
- Interactive Recharts: line, bar, area charts
- Cross-site comparison on the same chart
- Paginated data table with search

### Analysis (`/informe-agua/analisis`)

- Trends: moving averages, min/max per period
- Anomaly detection: values outside configurable standard deviation range
- Basic prediction: linear trend projection (short-term)

### Reports (`/informe-agua/reportes`)

- Predefined reports: daily, weekly, monthly per site
- Export to PDF (API route + html-to-pdf) and Excel (xlsx library)
- Scheduled reports: worker generates them, available for download

### Settings (`/informe-agua/config`)

- Saved dashboards: bookmark combinations of sites/variables/date ranges
- Alerts: custom thresholds per site/variable, visual notification on entry
- Preferences: theme, data density, units

## Worker (Pre-computation)

**Implementation:** Node script started via Next.js `instrumentation.ts` hook (runs on server startup).

**Cycle (every 5 minutes, configurable via `WORKER_INTERVAL_MS`):**

1. Read new entries from `historico_lectura` (track last processed `etiempo` in `worker_state`)
2. Compute aggregations: hourly, daily, weekly averages per site/variable
3. Anomaly detection: compare values against mean ± N standard deviations
4. Store results in `config.sqlite` aggregation/anomaly tables

**Benefit:** dashboards read from pre-computed tables, no heavy queries against reportespiolis database at request time.

**Error handling:** the worker wraps each cycle in try/catch. On failure, it logs the error with `[error]` tag and retries on the next interval with exponential backoff (up to 30 min max). It never crashes the main Next.js process. A `last_error` column in `worker_state` records the latest failure for healthcheck visibility.

## Authentication

Shared session with the SPA — no separate login.

**Cookie contract (from `telecom-spa/apps/spa/lib/auth.ts`):**

- **Cookie name:** `__session`
- **Cookie path:** `/` (sent to all routes including `/informe-agua/`)
- **Format:** `<payloadB64url>.<signatureB64url>`
- **Signing:** HMAC-SHA256 using `SESSION_SECRET` via Web Crypto API (`crypto.subtle`)
- **Payload:** `{ sub: string, role: string, exp: number }` (JSON, base64url-encoded)
- **Validation:** decode payload, verify HMAC signature, check `exp` > now
- **Secure flag:** controlled by `SESSION_COOKIE_SECURE` env var (default: true in production)

**Flow:**

1. User logs into SPA (`/`)
2. Receives `__session` cookie signed with HMAC-SHA256 using `SESSION_SECRET`
3. Navigates to `/informe-agua/` — cookie is sent (path is `/`)
4. informe-agua middleware reads `__session`, verifies HMAC-SHA256 with same `SESSION_SECRET`
5. Valid + not expired → extract `sub` (username) and `role`, allow access
6. Invalid or missing → redirect to `/login`

**Implementation:** port the `verifyToken()` function from the SPA's `lib/auth.ts` to a shared utility in informe-agua. Uses only Web Crypto API (available in Node 20+), no external dependencies.

**Env vars:** `SESSION_SECRET` (same as SPA, already in `.env`). No `users.json` or passwords needed — only validates sessions, does not authenticate.

## Design System

**Strategy:** design tokens + replicated base components.

- `design-tokens.ts` in the informe-agua repo with colors, typography, spacing, shadows extracted from the SPA
- Manually synchronized (no shared npm package — overkill for 2 apps)
- Replicated base components: layout, navbar, sidebar, buttons, cards
- Same font-family, border-radius, color palette
- Shared navbar with links to `/` (portal), `/reporte/`, and `/informe-agua/`
- User perceives a single unified application

## Changes to telecom-deploy

### docker-compose.yml — new service

```yaml
informe-agua:
  build:
    context: ./sources/telecom-informe-agua
    dockerfile: ../../dockerfiles/informe-agua.Dockerfile
  restart: unless-stopped
  expose:
    - "3000"
  environment:
    - NODE_ENV=production
    - SESSION_SECRET=${SESSION_SECRET}
    - REPORTES_DB_PATH=/app/data/reportes/database.sqlite
    - LOCAL_DB_PATH=/app/data/local/config.sqlite
    - WORKER_INTERVAL_MS=${WORKER_INTERVAL_MS:-300000}
  volumes:
    - ./data/reportes:/app/data/reportes
    - ./data/informe-agua:/app/data/local
  depends_on:
    reportespiolis:
      condition: service_healthy
  networks:
    - telecom_network
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL
  read_only: true
  tmpfs:
    - /tmp
  deploy:
    resources:
      limits:
        cpus: "1"
        memory: 768M
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "3"
  healthcheck:
    test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3000/informe-agua/').then(r => { if (!r.ok) throw 1 })"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s
```

**Note:** nginx's `depends_on` block must also be updated to include `informe-agua: condition: service_healthy`.

### nginx/nginx.conf — new routes

Next.js is configured with `basePath: '/informe-agua'`, so it expects requests with the prefix intact. The `proxy_pass` has no trailing slash (no prefix stripping).

```nginx
# Static assets for informe-agua (aggressive caching)
location ~ ^/informe-agua/_next/static/ {
    proxy_pass http://informe-agua:3000;
    proxy_http_version 1.1;
    expires 365d;
    access_log off;
    add_header Cache-Control "public, immutable";
}

# Bare /informe-agua → /informe-agua/ redirect
location = /informe-agua {
    return 301 /informe-agua/;
}

# informe-agua application routes
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

### New Dockerfile: `dockerfiles/informe-agua.Dockerfile`

Multi-stage like `spa.Dockerfile`:
- Builder: Node 20 Bookworm Slim, pnpm, build Next.js standalone
- Runner: Node 20 Alpine, copy standalone output, run as `node` user
- Supports `INSECURE_TLS_BUILD` build arg (same pattern as existing Dockerfiles)

### Scripts

- `setup`: add clone of `telecom-informe-agua` repo + create `data/informe-agua/` directory
- `actualizar`: add status check for the third repo
- `scripts/common.sh`: add `INFORME_AGUA_REPO_URL` and `INFORME_AGUA_REF` defaults

### .env.example

Add:
```bash
WORKER_INTERVAL_MS=300000   # Worker pre-computation interval (5 min)
```

## Logging

Follows project conventions:
- Structured log tags: `[info]`, `[warn]`, `[error]`
- Includes module identifier prefix (e.g., `[info] WORKER - ...`, `[error] AUTH - ...`)
- Uses `console.log`/`console.error` (captured by Docker json-file driver)

## Development Workflow

A `docker-compose.dev.yml` override will be added for informe-agua, following the same pattern as the existing SPA dev compose:
- Mount `sources/telecom-informe-agua` for hot-reload
- Use Node 20 Bookworm Slim (dev image) instead of Alpine
- Expose port for direct access during development

## Backup

The `data/informe-agua/` directory should be included in any existing backup strategy. It contains user-created dashboards, alert configurations, and preferences that cannot be regenerated from the reportespiolis database.

## Out of Scope

- Real-time websocket streaming (polling via worker is sufficient)
- Multi-tenant / role-based access (all authenticated users see everything)
- External notification channels (email/SMS alerts) — visual alerts only for now
- Mobile-specific layout (responsive web is enough)
- Cross-service API calls / CORS (informe-agua reads SQLite directly, no inter-service HTTP)
