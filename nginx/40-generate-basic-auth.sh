#!/bin/sh
set -eu

AUTH_USER="${BASIC_AUTH_USER:-change-me}"
AUTH_PASS="${BASIC_AUTH_PASS:-change-me-strong-password}"

AUTH_HASH="$(openssl passwd -6 "$AUTH_PASS")"
printf '%s:%s\n' "$AUTH_USER" "$AUTH_HASH" > /tmp/.htpasswd

if chown root:nginx /tmp/.htpasswd 2>/dev/null; then
  chmod 640 /tmp/.htpasswd
else
  chmod 644 /tmp/.htpasswd
fi
