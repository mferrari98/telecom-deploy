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

**Stack:** Next.js (standalone), Node 20, pnpm, Recharts, SQLite (better-sqlite3)

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

## Authentication

Shared session with the SPA — no separate login.

**Flow:**

1. User logs into SPA (`/`)
2. Receives session cookie signed with `SESSION_SECRET`
3. Navigates to `/informe-agua/` — Nginx routes to new service
4. informe-agua reads cookie, verifies signature with same `SESSION_SECRET`
5. Valid → extract user, allow access
6. Invalid or missing → redirect to `/` (SPA login)

**Requirement:** replicate SPA's cookie validation logic. Exact format determined during implementation by reading telecom-spa auth code.

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
    context: .
    dockerfile: dockerfiles/informe-agua.Dockerfile
  restart: unless-stopped
  ports: []
  expose:
    - "3000"
  environment:
    - NODE_ENV=production
    - SESSION_SECRET=${SESSION_SECRET}
    - REPORTES_DB_PATH=/app/data/reportes/database.sqlite
    - LOCAL_DB_PATH=/app/data/local/config.sqlite
    - WORKER_INTERVAL_MS=${WORKER_INTERVAL_MS:-300000}
  volumes:
    - ./data/reportes:/app/data/reportes:ro
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
        memory: 512M
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "3"
  healthcheck:
    test: ["CMD", "node", "-e", "fetch('http://localhost:3000').then(r => { if (!r.ok) throw 1 })"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s
```

### nginx/nginx.conf — new route

```nginx
location /informe-agua/ {
    limit_req zone=api burst=20 nodelay;
    proxy_pass http://informe-agua:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Prefix /informe-agua;
    proxy_read_timeout 120s;
}
```

### New Dockerfile: `dockerfiles/informe-agua.Dockerfile`

Multi-stage like `spa.Dockerfile`:
- Builder: Node 20 Bookworm Slim, pnpm, build Next.js standalone
- Runner: Node 20 Alpine, copy standalone output, run as `node` user

### Scripts

- `setup`: add clone of `telecom-informe-agua` repo + create `data/informe-agua/` directory
- `actualizar`: add status check for the third repo
- `scripts/common.sh`: add `INFORME_AGUA_REPO_URL` default

### .env.example

Add:
```bash
WORKER_INTERVAL_MS=300000   # Worker pre-computation interval (5 min)
```

## Out of Scope

- Real-time websocket streaming (polling via worker is sufficient)
- Multi-tenant / role-based access (all authenticated users see everything)
- External notification channels (email/SMS alerts) — visual alerts only for now
- Mobile-specific layout (responsive web is enough)
