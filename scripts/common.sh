#!/usr/bin/env bash
# common.sh — Shared variables and helpers for telecom-deploy scripts.
# Source this file after setting ROOT_DIR:
#   ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "${ROOT_DIR}/scripts/common.sh"
set -euo pipefail

# --- .env loading -----------------------------------------------------------

if [ ! -f "${ROOT_DIR}/.env" ]; then
  cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  GENERATED_SECRET="$(openssl rand -hex 32)"
  sed -i "s|change-me-to-a-random-64-char-string|${GENERATED_SECRET}|" "${ROOT_DIR}/.env"
  echo "[info] Se creo .env desde .env.example"
  echo "[info] SESSION_SECRET generado automaticamente"
fi

set -a
. "${ROOT_DIR}/.env"
set +a

# --- Defaults ----------------------------------------------------------------

SPA_REPO_URL="${SPA_REPO_URL:-https://github.com/mferrari98/telecom-spa.git}"
SPA_REF="${SPA_REF:-main}"
REPORTES_REPO_URL="${REPORTES_REPO_URL:-https://github.com/mferrari98/telecom-reportespiolis.git}"
REPORTES_REF="${REPORTES_REF:-main}"

SOURCES_DIR="${ROOT_DIR}/sources"

# --- Credential checks -------------------------------------------------------

is_insecure_session_secret() {
  case "$1" in
    ""|"change-me-to-a-random-64-char-string")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

warn_insecure_credentials() {
  if is_insecure_session_secret "${SESSION_SECRET:-}"; then
    echo "[warn] SESSION_SECRET usa un valor placeholder o esta vacio."
    echo "[warn] Genera uno seguro: openssl rand -hex 32"
    echo
  fi
}
