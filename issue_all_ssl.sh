#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-hello@hashtax.io}"

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
echo "    Hashtax & HashImpact - Unified SSL Issuer     "
echo "=================================================="

activate_http_only() {
  local active_conf="$1"
  local http_template="$2"

  cp -f "$http_template" "$active_conf"
}

activate_ssl_if_present() {
  local active_conf="$1"
  local ssl_template="$2"
  local cert_dir="$3"

  if $COMPOSE_CMD exec -T nginx_gateway sh -c "test -f '${cert_dir}/fullchain.pem' && test -f '${cert_dir}/privkey.pem'"; then
    cp -f "$ssl_template" "$active_conf"
  else
    echo "⚠️  Missing certificate files in nginx_gateway:${cert_dir}; keeping ${active_conf} on HTTP-only config."
    activate_http_only "$active_conf" "${ssl_template%.ssl.conf.disabled}.http.conf.disabled"
  fi
}

# 1. Ensure network exists
docker network create hashtax_network >/dev/null 2>&1 || true

# 2. Reset configs to HTTP-only to ensure Nginx can start
echo "--> Setting HTTP-only configs for ACME challenge..."
cp -f conf.d/hashimpact.conf conf.d/hashimpact.http.conf.backup || true
cp -f conf.d/tools.conf conf.d/tools.http.conf.backup || true
cp -f conf.d/hashimpact.http.conf.disabled conf.d/hashimpact.conf
cp -f conf.d/tools.http.conf.disabled conf.d/tools.conf

echo "--> Starting/Restarting Nginx gateway..."
$COMPOSE_CMD up -d nginx_gateway
sleep 3 # Wait for nginx to initialize

# 3. Issue cert for HashImpact
echo "--> Requesting certificate for hashimpact.io and api.hashimpact.io..."
if ! $COMPOSE_CMD --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d hashimpact.io \
  -d api.hashimpact.io \
  --email "${EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --non-interactive; then
  echo "⚠️ HashImpact SSL issuance failed; will keep HTTP-only until cert files exist."
fi

# 4. Issue cert for Tools
echo "--> Requesting certificate for tools.hashtax.io and tools-api.hashtax.io..."
if ! $COMPOSE_CMD --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d tools.hashtax.io \
  -d tools-api.hashtax.io \
  --email "${EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --non-interactive; then
  echo "⚠️ Tools SSL issuance failed; will keep HTTP-only until cert files exist."
fi

# 5. Activate SSL configs
echo "--> Activating HTTPS configs..."
activate_ssl_if_present \
  conf.d/hashimpact.conf \
  conf.d/hashimpact.ssl.conf.disabled \
  /etc/letsencrypt/live/hashimpact.io

activate_ssl_if_present \
  conf.d/tools.conf \
  conf.d/tools.ssl.conf.disabled \
  /etc/letsencrypt/live/tools.hashtax.io

# 6. Reload Nginx
echo "--> Reloading Nginx gateway..."
$COMPOSE_CMD exec -T nginx_gateway nginx -t && $COMPOSE_CMD exec -T nginx_gateway nginx -s reload

echo "=================================================="
echo " ✅ SSL setup/check complete!"
echo "=================================================="
