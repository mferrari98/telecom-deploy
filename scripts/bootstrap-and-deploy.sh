#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

DEPLOY=1
COMPOSE_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --setup-only)
      DEPLOY=0
      ;;
    *)
      COMPOSE_ARGS+=("$arg")
      ;;
  esac
done

. "${ROOT_DIR}/scripts/common.sh"

warn_insecure_credentials

SPA_DIR="${SOURCES_DIR}/telecom-spa"
REPORTES_DIR="${SOURCES_DIR}/telecom-reportespiolis"

clone_or_update_repo() {
  local repo_url="$1"
  local repo_ref="$2"
  local repo_dir="$3"

  if [ -d "${repo_dir}/.git" ]; then
    echo "Updating $(basename "${repo_dir}") (${repo_ref})"
    git -C "${repo_dir}" fetch --tags origin
    git -C "${repo_dir}" checkout "${repo_ref}"
    if git -C "${repo_dir}" symbolic-ref -q HEAD >/dev/null 2>&1 && git -C "${repo_dir}" rev-parse --verify "origin/${repo_ref}" >/dev/null 2>&1; then
      git -C "${repo_dir}" pull --ff-only origin "${repo_ref}"
    fi
  else
    echo "Cloning $(basename "${repo_dir}") (${repo_ref})"
    rm -rf "${repo_dir}"
    git clone "${repo_url}" "${repo_dir}"
    git -C "${repo_dir}" checkout "${repo_ref}"
  fi
}

mkdir -p "${SOURCES_DIR}"

clone_or_update_repo "${SPA_REPO_URL}" "${SPA_REF}" "${SPA_DIR}"
clone_or_update_repo "${REPORTES_REPO_URL}" "${REPORTES_REF}" "${REPORTES_DIR}"

if [ ! -f "${REPORTES_DIR}/.env" ]; then
  if [ -f "${REPORTES_DIR}/example-env" ]; then
    cp "${REPORTES_DIR}/example-env" "${REPORTES_DIR}/.env"
    echo "Created ${REPORTES_DIR}/.env from example-env"
  elif [ -f "${REPORTES_DIR}/.env.example" ]; then
    cp "${REPORTES_DIR}/.env.example" "${REPORTES_DIR}/.env"
    echo "Created ${REPORTES_DIR}/.env from .env.example"
  fi
fi

# Ensure host-side bind-mount directories exist with correct ownership
# (UID 1000 = node user inside the container)
for dir in data/reportes data/reportes-logs; do
  if [ ! -d "${ROOT_DIR}/${dir}" ]; then
    mkdir -p "${ROOT_DIR}/${dir}"
  fi
  if [ "$(stat -c '%u' "${ROOT_DIR}/${dir}")" != "1000" ]; then
    echo "[info] Fixing ownership of ${dir} → UID 1000"
    chown 1000:1000 "${ROOT_DIR}/${dir}"
  fi
done

if [ "${DEPLOY}" -eq 1 ]; then
  docker compose -p webtelecom up -d --build --remove-orphans "${COMPOSE_ARGS[@]}"
else
  echo
  echo "Setup listo. Para arrancar los contenedores ejecuta:"
  echo "docker compose -p webtelecom up -d --build --remove-orphans"
fi
