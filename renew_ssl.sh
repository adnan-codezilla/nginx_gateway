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

# Let certbot renew any certificates that are near expiry
if ! $COMPOSE_CMD --profile certbot run --rm certbot renew \
  --webroot -w /var/www/certbot \
  --quiet; then
  echo "⚠️ Certificate renewal reported an error."
fi

if [[ -f /etc/letsencrypt/live/hashimpact.io/fullchain.pem && -f /etc/letsencrypt/live/tools.hashtax.io/fullchain.pem ]]; then
  # Reload Nginx to pick up any new certificates
  $COMPOSE_CMD exec -T nginx_gateway nginx -s reload
else
  echo "⚠️ One or more certificate files are missing; skipping nginx reload."
fi

echo "✅ Renewal check complete."
