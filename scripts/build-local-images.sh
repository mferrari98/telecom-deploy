#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SPA_REPO="${SPA_REPO:-${ROOT_DIR}/web-telecom}"
REPORTES_REPO="${REPORTES_REPO:-${ROOT_DIR}/servicios-telecom/cont-reportespiolis}"

echo "Building SPA image from: ${SPA_REPO}"
docker build -t webtelecom-spa:latest -f "${SPA_REPO}/apps/spa/Dockerfile" "${SPA_REPO}"

echo "Building reportes image from: ${REPORTES_REPO}"
docker build -t webtelecom-reportespiolis:latest -f "${REPORTES_REPO}/Dockerfile" "${REPORTES_REPO}"

echo "Done. Images available:"
echo "- webtelecom-spa:latest"
echo "- webtelecom-reportespiolis:latest"
