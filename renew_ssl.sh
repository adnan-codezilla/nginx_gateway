#!/usr/bin/env bash
set -euo pipefail

# Detect docker compose version
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "❌ Error: Neither 'docker compose' nor 'docker-compose' found."
  exit 1
fi

echo "=================================================="
echo "    Hashtax & HashImpact - SSL Auto-Renewer       "
echo "=================================================="

activate_ssl_if_present() {
  local active_conf="$1"
  local ssl_template="$2"
  local cert_dir="$3"

  if $COMPOSE_CMD exec -T nginx_gateway sh -c "test -f '${cert_dir}/fullchain.pem' && test -f '${cert_dir}/privkey.pem'"; then
    cp -f "$ssl_template" "$active_conf"
  else
    echo "⚠️ Missing certificate files in nginx_gateway:${cert_dir}; leaving ${active_conf} unchanged."
  fi
}

# Let certbot renew any certificates that are near expiry
if ! $COMPOSE_CMD --profile certbot run --rm certbot renew \
  --webroot -w /var/www/certbot \
  --quiet; then
  echo "⚠️ Certificate renewal reported an error."
fi

activate_ssl_if_present \
  conf.d/hashimpact.conf \
  conf.d/hashimpact.ssl.conf.disabled \
  /etc/letsencrypt/live/hashimpact.io

activate_ssl_if_present \
  conf.d/tools.conf \
  conf.d/tools.ssl.conf.disabled \
  /etc/letsencrypt/live/tools.hashtax.io

$COMPOSE_CMD exec -T nginx_gateway nginx -t
$COMPOSE_CMD exec -T nginx_gateway nginx -s reload

echo "✅ Renewal check complete."
