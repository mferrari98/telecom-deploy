# AGENTS.md

Guidance for coding agents operating in `telecom-deploy`.

## Scope and repo shape
- Primary repo purpose: deployment orchestration (`docker-compose`, `nginx`, bootstrap/update scripts).
- Runtime entrypoint is `nginx` on HTTPS, proxying to `spa` and `reportespiolis`.
- Local source clones are under `sources/` (`telecom-spa`, `telecom-reportespiolis`).
- `sources/` is gitignored here; edits there are not committed to `telecom-deploy`.
- Most first-party code in this repo is shell, Dockerfiles, YAML, and nginx config.

## Where to look first
- Root docs: `README.md`, `MIGRATION.md`.
- Bootstrap/update scripts: `setup`, `actualizar`, `scripts/bootstrap-and-deploy.sh`.
- Infra config: `docker-compose.yml`, `nginx/nginx.conf`, `nginx/Dockerfile`.
- App image build contexts: `dockerfiles/spa.Dockerfile`, `dockerfiles/reportespiolis.Dockerfile`.

## Build, lint, and test commands

### telecom-deploy (root)
Setup + deploy:
```bash
cp .env.example .env
./setup
docker compose -p webtelecom up -d --build --remove-orphans
```
Update flows:
```bash
./actualizar
./actualizar --update
./actualizar --update --deploy
```
Useful ops:
```bash
docker compose -p webtelecom config
docker compose -p webtelecom logs -f nginx
docker compose -p webtelecom down
```
Static checks:
```bash
bash -n setup
bash -n actualizar
bash -n scripts/bootstrap-and-deploy.sh
sh -n nginx/40-generate-basic-auth.sh
```

### telecom-spa (`sources/telecom-spa`)
```bash
pnpm install
pnpm dev:spa
pnpm build:spa
pnpm typecheck
pnpm --filter @telecom/spa typecheck
pnpm --filter @telecom/spa build
pnpm docker:build:spa
```
Notes:
- Uses `pnpm` + `turbo` (`pnpm-workspace.yaml`, `turbo.json`).
- Node target is `>=20`.
- No lint script is currently defined.

### telecom-reportespiolis (`sources/telecom-reportespiolis`)
```bash
npm ci
npm start
npm test
```
Notes:
- `npm test` intentionally fails (`"no test specified"`).
- No dedicated lint command is defined.

## Single-test guidance (important)
There is no true unit/integration test runner configured in this repo family yet.
When asked for a "single test", use the narrowest equivalent and call it out explicitly:

1) Single script syntax check (deploy repo):
```bash
bash -n scripts/bootstrap-and-deploy.sh
```
2) Single package typecheck (SPA repo):
```bash
pnpm --filter @telecom/spa typecheck
```
3) Single endpoint smoke check (running stack):
```bash
curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/healthz
```
If real test tooling is added later, update this file with exact single-test commands.

## Code style and conventions

### General
- Preserve architecture and module boundaries; avoid drive-by refactors.
- Keep changes minimal and local; do not reformat untouched files.
- Follow language per folder: shell in deploy scripts, TS/React in SPA, CJS in reportes.
- Keep secrets out of git; `.env` is local-only and `.env.example` is template-only.

### Shell scripts (`setup`, `actualizar`, `scripts/*.sh`)
- Use `#!/usr/bin/env bash` + `set -euo pipefail` for bash scripts.
- Use `#!/bin/sh` + `set -eu` only when POSIX shell is intentional.
- Prefer helper functions and `local` variables.
- Quote all expansions (`"$var"`), especially paths/user inputs.
- Use uppercase for env/config constants (`ROOT_DIR`, `SOURCES_DIR`, etc.).
- Parse flags with `case`; provide `-h|--help` when relevant.
- Emit clear tagged logs (`[info]`, `[warn]`, `[error]`).

### Dockerfiles / Compose / nginx
- Keep two-space indentation in YAML and match existing nginx style.
- Preserve current security posture (`read_only`, `tmpfs`, `no-new-privileges`).
- Keep interpolation style `${VAR:-default}` in compose files.
- In Dockerfiles, chain installs carefully and clean apt caches.
- Do not weaken TLS/auth defaults or remove healthchecks unless requested.

### TypeScript/React (`sources/telecom-spa`)
- TS runs in strict mode; avoid `any` and use explicit payload/prop types.
- Prefer `type` aliases for payloads/props.
- Import order used in routes/components: `node:*` built-ins, external deps, internal/workspace imports.
- Use `PascalCase` for components/types, `camelCase` for vars/functions.
- Use `UPPER_SNAKE_CASE` for module constants.
- Keep API routes defensive (parse/validate numbers, safe fallbacks).
- Return safe error payloads/statuses; avoid leaking internals.

### Node/Express CJS (`sources/telecom-reportespiolis`)
- Use CommonJS consistently (`require`, `module.exports`).
- Keep semicolon-heavy style to match existing files.
- Preserve module ID constants like `ID_MOD` for log context.
- Use shared wrappers (`asyncHandler`) for async route handlers.
- Throw/propagate `AppError` and `ValidationError` for HTTP-facing failures.
- Prefer central logging via `logamarillo(...)` over ad-hoc `console.*`.

### Error handling
- Fail fast on bootstrap/startup failures.
- Use safe fallbacks (`null`/defaults) only for intentionally optional reads.
- Avoid empty catches unless suppression is deliberate and justified.
- Include enough context in logs for operator diagnosis.

### Security and config hygiene
- Never commit real credentials, keys, or production host details.
- Keep placeholders (`change-me`, `change-me-strong-password`) only in templates.
- Preserve credential warnings enforced by setup/update scripts.
- Prefer existing env-loading pattern: `set -a; . ./.env; set +a`.

## Cursor and Copilot rules check
Searched for:
- `.cursor/rules/`
- `.cursorrules`
- `.github/copilot-instructions.md`

Result at time of writing: none found in this repository.
If those files are added later, update this document to mirror them.
