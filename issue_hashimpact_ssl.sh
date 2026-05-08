#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-hello@hashtax.io}"

docker network create hashtax_network >/dev/null 2>&1 || true

echo "Starting gateway"
cp -f conf.d/hashimpact.http.conf.disabled conf.d/hashimpact.conf
docker compose up -d nginx_gateway

echo "Requesting certificate for hashimpact.io and api.hashimpact.io"
docker compose --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d hashimpact.io \
  -d api.hashimpact.io \
  --email "${EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --non-interactive

echo "Activating HashImpact HTTPS config"
cp conf.d/hashimpact.ssl.conf.disabled conf.d/hashimpact.conf

echo "Certificate is installed. Reloading gateway"
docker compose restart nginx_gateway

echo "HashImpact SSL is installed and HTTPS routing is active."
