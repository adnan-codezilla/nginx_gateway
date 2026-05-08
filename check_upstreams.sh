#!/usr/bin/env bash
set -euo pipefail

UPSTREAMS=(
  "hashtax_frontend:3000"
  "hashtax_backend:5000"
  "hashimpact_frontend:8081"
  "hashimpact_backend:8080"
)

echo "== Containers on hashtax_network =="
docker network inspect hashtax_network \
  --format '{{range $id, $c := .Containers}}{{println $c.Name $c.IPv4Address}}{{end}}' \
  | sort

echo
echo "== DNS from nginx_gateway =="
for upstream in "${UPSTREAMS[@]}"; do
  host="${upstream%%:*}"
  port="${upstream##*:}"

  printf "%-25s " "${host}"
  if docker exec nginx_gateway getent hosts "${host}" >/tmp/nginx_upstream_host 2>/dev/null; then
    cat /tmp/nginx_upstream_host
  else
    echo "NOT RESOLVED"
    continue
  fi

  printf "%-25s " "${host}:${port}"
  if docker exec nginx_gateway sh -c "nc -z -w 2 ${host} ${port}" >/dev/null 2>&1; then
    echo "PORT OK"
  else
    echo "PORT CLOSED"
  fi
done
