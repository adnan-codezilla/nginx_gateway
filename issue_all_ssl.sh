#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-hello@hashtax.io}"

echo "=================================================="
echo "    Hashtax & HashImpact - Unified SSL Issuer     "
echo "=================================================="

# 1. Ensure network exists
docker network create hashtax_network >/dev/null 2>&1 || true

# 2. Reset configs to HTTP-only to ensure Nginx can start
echo "--> Setting HTTP-only configs for ACME challenge..."
cp -f conf.d/hashimpact.conf conf.d/hashimpact.http.conf.backup || true
cp -f conf.d/tools.conf conf.d/tools.http.conf.backup || true

# In case we were stuck in a broken SSL state, overwrite with the safe templates we just created
# We'll just assume conf.d/hashimpact.conf and conf.d/tools.conf are already in HTTP mode,
# or we've manually placed them there. The gateway needs to be up to serve /.well-known/acme-challenge.

echo "--> Starting/Restarting Nginx gateway..."
docker compose up -d nginx_gateway
sleep 3 # Wait for nginx to initialize

# 3. Issue cert for HashImpact
if [ ! -f "/etc/letsencrypt/live/hashimpact.io/fullchain.pem" ]; then
    echo "--> Requesting certificate for hashimpact.io and api.hashimpact.io..."
    docker compose --profile certbot run --rm certbot certonly \
      --webroot -w /var/www/certbot \
      -d hashimpact.io \
      -d api.hashimpact.io \
      --email "${EMAIL}" \
      --agree-tos \
      --no-eff-email \
      --non-interactive
else
    echo "--> Certificate for HashImpact already exists. Skipping."
fi

# 4. Issue cert for Tools
if [ ! -f "/etc/letsencrypt/live/tools.hashtax.io/fullchain.pem" ]; then
    echo "--> Requesting certificate for tools.hashtax.io and tools-api.hashtax.io..."
    docker compose --profile certbot run --rm certbot certonly \
      --webroot -w /var/www/certbot \
      -d tools.hashtax.io \
      -d tools-api.hashtax.io \
      --email "${EMAIL}" \
      --agree-tos \
      --no-eff-email \
      --non-interactive
else
    echo "--> Certificate for Tools already exists. Skipping."
fi

# 5. Activate SSL configs
echo "--> Activating HTTPS configs..."
# Only copy if the target cert actually exists now
[ -f "/etc/letsencrypt/live/hashimpact.io/fullchain.pem" ] && cp -f conf.d/hashimpact.ssl.conf.disabled conf.d/hashimpact.conf
[ -f "/etc/letsencrypt/live/tools.hashtax.io/fullchain.pem" ] && cp -f conf.d/tools.ssl.conf.disabled conf.d/tools.conf

# 6. Reload Nginx
echo "--> Reloading Nginx gateway..."
docker compose exec -T nginx_gateway nginx -s reload

echo "=================================================="
echo " ✅ SSL setup/check complete!"
echo "=================================================="
