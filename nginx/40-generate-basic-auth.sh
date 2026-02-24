#!/bin/sh
set -eu

AUTH_USER="${BASIC_AUTH_USER:-change-me}"
AUTH_PASS="${BASIC_AUTH_PASS:-change-me-strong-password}"

AUTH_HASH="$(openssl passwd -apr1 "$AUTH_PASS")"
printf '%s:%s\n' "$AUTH_USER" "$AUTH_HASH" > /etc/nginx/.htpasswd

if chown root:nginx /etc/nginx/.htpasswd 2>/dev/null; then
  chmod 640 /etc/nginx/.htpasswd
else
  chmod 644 /etc/nginx/.htpasswd
fi
