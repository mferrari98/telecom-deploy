# Env Secret Lockdown Design

## Goal

Reduce immediate credential exposure risk in deploy workflows without changing runtime architecture, TLS model, or app behavior.

## Scope

- Stop relying on weak fallback credentials (`comu` / `adminwiz`) in scripts and auth generation.
- Keep only placeholder values in tracked env templates.
- Ensure local runtime `.env` remains untracked and validated before deploy.
- Preserve current source-bootstrap flow (`./setup` then `docker compose -p webtelecom up -d --build --remove-orphans`).

## Non-Goals

- No replacement of self-signed certs.
- No `reportespiolis` application logic changes.
- No migration to registry-first deployment.

## Approach

### 1) Fail-safe credential defaults

- Replace script-level fallback Basic Auth defaults with explicit placeholders.
- Treat missing, placeholder, or known weak values as insecure.
- Emit clear actionable warnings in setup/update paths; avoid silent insecure startup assumptions.

### 2) Template and docs enforcement

- Keep `.env.example` and `.env.stack.example` with placeholder-only values.
- Update documentation to state that real secrets must exist only in local `.env`.
- Keep setup behavior unchanged (prepare environment, do not auto-start containers).

### 3) Runtime compatibility

- Preserve compose variable wiring and Nginx auth-file generation behavior.
- Continue generating hash into writable tmp path for read-only root filesystem.
- Ensure no behavior change for users that already configured non-default credentials.

## Data Flow / Validation

1. User runs `./setup` or `./actualizar`.
2. Script loads `.env` and computes effective auth credentials.
3. Script validates credentials against deny-list (`change-me`, `change-me-strong-password`, `comu`, `adminwiz`, empty).
4. If insecure values are detected, user receives explicit warning with remediation step.
5. During container startup, Nginx auth generator uses provided credentials and writes `/tmp/.htpasswd`.

## Error Handling

- Missing `.env`: auto-create from `.env.example` (existing behavior).
- Insecure credentials: warn loudly with concrete fix instructions.
- Invalid/missing env values for compose: rely on compose substitution defaults plus script validation messaging.

## Verification

- Config checks:
  - `docker compose -p webtelecom config`
- Functional checks:
  - `./setup` prints setup-only command and does not start containers.
  - `docker compose -p webtelecom up -d --build --remove-orphans` succeeds.
  - `https://localhost/healthz` returns `200` without auth.
  - `https://localhost/` returns `401` unauthenticated.
  - Authenticated route returns `200` with non-default credentials.

## Risks and Mitigations

- Risk: existing operators still use weak local creds.
  - Mitigation: deny-list warnings in scripts and docs; placeholder-only templates.
- Risk: too-strict blocking could disrupt current workflows.
  - Mitigation: start with warnings (not hard-fail), then optionally escalate later.
