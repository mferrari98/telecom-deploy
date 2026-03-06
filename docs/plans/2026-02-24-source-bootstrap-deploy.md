# Source Bootstrap Deploy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy stack by cloning `telecom-spa` and `telecom-reportespiolis` over HTTPS, then building containers on `docker compose up --build`.

**Architecture:** Keep `telecom-deploy` as orchestrator repo. Add a bootstrap script that ensures local source checkouts under `sources/`, prepares required `.env` files, then runs compose build/up. Compose services `spa` and `reportespiolis` switch from prebuilt images to local `build.context` paths.

**Tech Stack:** Docker Compose, Bash, Git (HTTPS), Nginx.

---

### Task 1: Switch compose to source-based build

**Files:**
- Modify: `docker-compose.yml`

**Step 1: Change SPA service to local build context**

Update `spa` with:

```yaml
build:
  context: ./sources/telecom-spa
  dockerfile: apps/spa/Dockerfile
```

**Step 2: Change reportes service to local build context**

Update `reportespiolis` with:

```yaml
build:
  context: ./sources/telecom-reportespiolis
  dockerfile: Dockerfile
```

**Step 3: Validate compose syntax**

Run: `docker compose -p webtelecom -f docker-compose.yml config`
Expected: render succeeds without errors.

### Task 2: Add bootstrap script

**Files:**
- Create: `scripts/bootstrap-and-deploy.sh`
- Modify: `.env.example`
- Modify: `.gitignore`

**Step 1: Create bootstrap script**

Script responsibilities:
- create `.env` from `.env.example` if missing
- load `.env`
- clone/update repos over HTTPS into `sources/`
- create reportes `.env` from example if missing
- run `docker compose -p webtelecom up -d --build --remove-orphans`

**Step 2: Add repo URL/ref variables to `.env.example`**

Include:
- `SPA_REPO_URL`, `SPA_REF`
- `REPORTES_REPO_URL`, `REPORTES_REF`

**Step 3: Ignore local source clones**

Add `sources/` to `.gitignore`.

### Task 3: Update docs and remove obsolete workflow path

**Files:**
- Modify: `README.md`
- Modify: `MIGRATION.md`
- Delete: `scripts/build-local-images.sh`

**Step 1: Document from-zero flow**

Add quickstart:

```bash
git clone https://github.com/mferrari98/telecom-deploy.git
cd telecom-deploy
cp .env.example .env
./scripts/bootstrap-and-deploy.sh
```

**Step 2: Update migration notes**

Replace image-publish references with source bootstrap flow.

**Step 3: Remove obsolete local image build helper**

Delete `scripts/build-local-images.sh` to avoid conflicting deploy paths.

### Task 4: Verification

**Files:**
- N/A

**Step 1: Validate compose**

Run: `docker compose -p webtelecom -f docker-compose.yml config`
Expected: `OK`/rendered config.

**Step 2: Run bootstrap deploy**

Run: `./scripts/bootstrap-and-deploy.sh`
Expected: repos cloned/updated and containers started.

**Step 3: Validate entrypoints**

Run:

```bash
curl -k -sS -o /dev/null -w "%{http_code}\n" https://localhost/
curl -k -sS -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" -o /dev/null -w "%{http_code}\n" https://localhost/monitor/
curl -k -sS -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" -o /dev/null -w "%{http_code}\n" https://localhost/reporte/
```

Expected:
- unauthenticated `/` => `401`
- authenticated routes => `200`
