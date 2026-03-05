#!/bin/sh
set -eu

# Read from Docker secrets with fallback to environment variables
if [ -f /run/secrets/basic_auth_user ]; then
  AUTH_USER="$(cat /run/secrets/basic_auth_user)"
else
  AUTH_USER="${BASIC_AUTH_USER:-change-me}"
fi

if [ -f /run/secrets/basic_auth_pass ]; then
  AUTH_PASS="$(cat /run/secrets/basic_auth_pass)"
else
  AUTH_PASS="${BASIC_AUTH_PASS:-change-me-strong-password}"
fi

AUTH_HASH="$(openssl passwd -6 "$AUTH_PASS")"
printf '%s:%s\n' "$AUTH_USER" "$AUTH_HASH" > /tmp/.htpasswd

if chown root:nginx /tmp/.htpasswd 2>/dev/null; then
  chmod 640 /tmp/.htpasswd
else
  chmod 644 /tmp/.htpasswd
fi
