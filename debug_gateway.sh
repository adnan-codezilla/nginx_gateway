#!/usr/bin/env bash
set -euo pipefail

DOMAINS=(
  "https://tools.hashtax.io/"
  "https://tools-api.hashtax.io/"
  "https://hashimpact.io/"
  "https://api.hashimpact.io/"
)

CONTAINERS=(
  nginx_gateway
  hashtax_frontend
  hashtax_backend
  hashimpact_frontend
  hashimpact_backend
)

echo "== Docker status =="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "== Nginx resolver =="
docker exec nginx_gateway sh -c "cat /etc/nginx/conf.d/00-resolver.conf"

echo
echo "== Network attachments =="
docker network inspect hashtax_network \
  --format '{{range $id, $c := .Containers}}{{println $c.Name $c.IPv4Address}}{{end}}' \
  | sort

echo
echo "== Upstream DNS from nginx =="
for name in hashtax_frontend hashtax_backend hashimpact_frontend hashimpact_backend; do
  printf "%-24s" "${name}"
  docker exec nginx_gateway getent hosts "${name}" || true
done

echo
echo "== App listening ports =="
for item in "hashtax_frontend 3000 0BB8" "hashtax_backend 5000 1388" "hashimpact_frontend 8081 1F91" "hashimpact_backend 8080 1F90"; do
  set -- ${item}
  name="$1"
  port="$2"
  hex="$3"
  printf "%-24s" "${name}:${port}"
  if docker exec "${name}" sh -c "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -qi ':${hex} '" >/dev/null 2>&1; then
    echo "LISTENING"
  else
    echo "NOT LISTENING"
  fi
done

echo
echo "== External HTTP status sample =="
for url in "${DOMAINS[@]}"; do
  printf "%-35s" "${url}"
  curl -k -sS -o /dev/null -w "%{http_code} connect=%{time_connect}s total=%{time_total}s\n" "${url}" || true
done

echo
echo "== Recent nginx errors =="
docker logs --tail=80 nginx_gateway 2>&1 | grep -Ei "error|emerg|warn|upstream|resolved|502|bad gateway" || true

echo
echo "== Recent app logs =="
for name in "${CONTAINERS[@]}"; do
  echo "-- ${name} --"
  docker logs --tail=30 "${name}" 2>&1 || true
done
