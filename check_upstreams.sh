#!/usr/bin/env bash
set -euo pipefail

UPSTREAMS=(
  "hashtax_frontend:3000:0BB8"
  "hashtax_backend:5000:1388"
  "hashimpact_frontend:8081:1F91"
  "hashimpact_backend:8080:1F90"
)

echo "== Containers on hashtax_network =="
docker network inspect hashtax_network \
  --format '{{range $id, $c := .Containers}}{{println $c.Name $c.IPv4Address}}{{end}}' \
  | sort

echo
echo "== DNS from nginx_gateway =="
if docker exec nginx_gateway sh -c "command -v nc" >/dev/null 2>&1; then
  HAS_NC=1
else
  HAS_NC=0
  echo "nginx_gateway has no nc command; skipping cross-container TCP probe."
fi

for upstream in "${UPSTREAMS[@]}"; do
  IFS=":" read -r host port port_hex <<< "${upstream}"

  printf "%-25s " "${host}"
  if docker exec nginx_gateway getent hosts "${host}" >/tmp/nginx_upstream_host 2>/dev/null; then
    cat /tmp/nginx_upstream_host
  else
    echo "NOT RESOLVED"
    continue
  fi

  if [ "${HAS_NC}" -eq 1 ]; then
    printf "%-25s " "${host}:${port}"
    if docker exec nginx_gateway sh -c "nc -z -w 2 ${host} ${port}" >/dev/null 2>&1; then
      echo "PORT OK"
    else
      echo "PORT CLOSED"
    fi
  fi

  printf "%-25s " "${host} listens:${port}"
  if docker exec "${host}" sh -c "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -qi ':${port_hex} '" >/dev/null 2>&1; then
    echo "YES"
  else
    echo "NO"
  fi
done
