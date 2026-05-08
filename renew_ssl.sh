#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "    Hashtax & HashImpact - SSL Auto-Renewer       "
echo "=================================================="

# Let certbot renew any certificates that are near expiry
docker compose --profile certbot run --rm certbot renew \
  --webroot -w /var/www/certbot \
  --quiet

# Reload Nginx to pick up any new certificates
docker compose exec -T nginx_gateway nginx -s reload

echo "✅ Renewal check complete."
