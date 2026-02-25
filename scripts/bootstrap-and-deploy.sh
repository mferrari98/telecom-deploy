#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

set -a
. ./.env
set +a

SPA_REPO_URL="${SPA_REPO_URL:-https://github.com/mferrari98/telecom-spa.git}"
SPA_REF="${SPA_REF:-main}"
REPORTES_REPO_URL="${REPORTES_REPO_URL:-https://github.com/mferrari98/telecom-reportespiolis.git}"
REPORTES_REF="${REPORTES_REF:-main}"

SOURCES_DIR="${ROOT_DIR}/sources"
SPA_DIR="${SOURCES_DIR}/telecom-spa"
REPORTES_DIR="${SOURCES_DIR}/telecom-reportespiolis"

clone_or_update_repo() {
  local repo_url="$1"
  local repo_ref="$2"
  local repo_dir="$3"

  if [ -d "${repo_dir}/.git" ]; then
    echo "Updating $(basename "${repo_dir}") (${repo_ref})"
    git -C "${repo_dir}" fetch origin "${repo_ref}"
    git -C "${repo_dir}" checkout "${repo_ref}"
    git -C "${repo_dir}" pull --ff-only origin "${repo_ref}"
  else
    echo "Cloning $(basename "${repo_dir}") (${repo_ref})"
    rm -rf "${repo_dir}"
    git clone --branch "${repo_ref}" --single-branch "${repo_url}" "${repo_dir}"
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

docker compose -p webtelecom up -d --build --remove-orphans "$@"
