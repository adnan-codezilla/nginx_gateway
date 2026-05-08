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
$COMPOSE_CMD --profile certbot run --rm certbot renew \
  --webroot -w /var/www/certbot \
  --quiet

# Reload Nginx to pick up any new certificates
$COMPOSE_CMD exec -T nginx_gateway nginx -s reload

echo "✅ Renewal check complete."
