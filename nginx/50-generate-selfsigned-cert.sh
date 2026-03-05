#!/bin/sh
set -eu

CERT_DIR="/etc/nginx/certs"
CERT_FILE="${CERT_DIR}/selfsigned.crt"
KEY_FILE="${CERT_DIR}/selfsigned.key"

if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
  echo "[info] TLS cert already exists, skipping generation"
  return 0 2>/dev/null || exit 0
fi

mkdir -p "${CERT_DIR}"

echo "[info] Generating self-signed TLS certificate"
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -subj "/C=AR/ST=BuenosAires/L=BuenosAires/O=Telecom/OU=Infra/CN=localhost"

echo "[info] TLS certificate generated at ${CERT_DIR}"
