# Env Secret Lockdown Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove weak credential fallbacks from deploy and SPA-infra scripts, enforce placeholder-only templates, and validate secure local credentials before deploy operations.

**Architecture:** Keep the current source-bootstrap deployment model and HTTPS+Basic Auth topology unchanged. Add a shared deny-list check in deploy scripts, switch auth script fallbacks to placeholders, and align SPA infra fallback scripts with the same secure defaults. Validate with shell syntax checks, compose render, and runtime auth checks.

**Tech Stack:** Bash, Docker Compose, Nginx, Next.js monorepo docs.

---

### Task 1: Harden deploy script defaults and validation

**Files:**
- Modify: `scripts/bootstrap-and-deploy.sh`

**Step 1: Write the failing validation probe**

Run:

```bash
BASIC_AUTH_USER=comu BASIC_AUTH_PASS=adminwiz ./scripts/bootstrap-and-deploy.sh --setup-only
```

Expected: output only warns about placeholder values, but does not identify weak legacy defaults.

**Step 2: Implement minimal secure validation**

- Replace `comu/adminwiz` fallbacks with `change-me`/`change-me-strong-password`.
- Add deny-list validation for empty, placeholder, and weak legacy values.
- Emit a strong warning with exact remediation (`editar .env`).

**Step 3: Run shell syntax verification**

Run:

```bash
bash -n scripts/bootstrap-and-deploy.sh
```

Expected: no output, exit code 0.

**Step 4: Re-run validation probe**

Run:

```bash
BASIC_AUTH_USER=comu BASIC_AUTH_PASS=adminwiz ./scripts/bootstrap-and-deploy.sh --setup-only
```

Expected: explicit warning that legacy weak credentials are insecure.

### Task 2: Add same validation path to update helper

**Files:**
- Modify: `actualizar`

**Step 1: Write failing behavior check**

Run:

```bash
BASIC_AUTH_USER=comu BASIC_AUTH_PASS=adminwiz ./actualizar
```

Expected: no warning for weak credentials.

**Step 2: Implement minimal parity check**

- Load and validate Basic Auth credentials with the same deny-list criteria as setup script.
- Print warning before repo/update/deploy actions.

**Step 3: Verify syntax and behavior**

Run:

```bash
bash -n actualizar && BASIC_AUTH_USER=comu BASIC_AUTH_PASS=adminwiz ./actualizar
```

Expected: syntax passes and warning appears.

### Task 3: Remove weak fallback values in auth-generator scripts

**Files:**
- Modify: `nginx/40-generate-basic-auth.sh`
- Modify: `../web-telecom/infra/docker/nginx/40-generate-basic-auth.sh`

**Step 1: Write failing check for legacy fallback literals**

Run:

```bash
rg -n "comu|adminwiz" nginx/40-generate-basic-auth.sh ../web-telecom/infra/docker/nginx/40-generate-basic-auth.sh
```

Expected: both files match.

**Step 2: Implement minimal secure defaults**

- Set both scripts to placeholder fallbacks only (`change-me`, `change-me-strong-password`).
- Keep hash algorithm and `/tmp/.htpasswd` behavior unchanged.

**Step 3: Verify checks**

Run:

```bash
bash -n nginx/40-generate-basic-auth.sh && bash -n ../web-telecom/infra/docker/nginx/40-generate-basic-auth.sh && rg -n "comu|adminwiz" nginx/40-generate-basic-auth.sh ../web-telecom/infra/docker/nginx/40-generate-basic-auth.sh
```

Expected: syntax passes; ripgrep returns no matches.

### Task 4: Tighten docs and templates for secret hygiene

**Files:**
- Modify: `README.md`
- Modify: `.env.example`
- Modify: `../web-telecom/.env.stack.example`
- Modify: `../web-telecom/README.md`

**Step 1: Write failing policy check**

Run:

```bash
rg -n "comu|adminwiz|versionar \\.env|cambiar credenciales" README.md ../web-telecom/README.md .env.example ../web-telecom/.env.stack.example
```

Expected: docs may mention credential change but not explicit deny-list/rotation workflow.

**Step 2: Implement minimal policy text**

- Clarify that committed env files are templates only.
- Clarify that local `.env` secrets must be rotated from defaults before exposure.
- Keep instructions aligned with `./setup` setup-only behavior.

**Step 3: Re-run policy check**

Run:

```bash
rg -n "template|plantilla|no versionar \\.env|rotar|credenciales" README.md ../web-telecom/README.md
```

Expected: explicit secret hygiene guidance present.

### Task 5: Verify stack behavior after lockdown

**Files:**
- N/A

**Step 1: Compose render**

Run:

```bash
docker compose -p webtelecom config >/tmp/webtelecom-compose.out
```

Expected: config renders successfully.

**Step 2: Setup-only behavior**

Run:

```bash
./setup
```

Expected: repos/env prepared and command hint shown; containers are not started by setup.

**Step 3: Runtime functional checks**

Run:

```bash
docker compose -p webtelecom up -d --build --remove-orphans && curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/healthz && curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/
```

Expected: `200` on `/healthz`, `401` on `/` without auth.

**Step 4: Auth check with configured credentials**

Run:

```bash
set -a; . ./.env; set +a; curl -k -sS -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASS}" -o /dev/null -w "%{http_code}\n" https://localhost/monitor/
```

Expected: `200` with configured credentials.
