# Shared Nginx Gateway

This gateway owns ports `80` and `443` for all projects on this server.

It routes:

- `tools.hashtax.io` -> `hashtax_frontend:3000`
- `tools-api.hashtax.io` -> `hashtax_backend:5000`
- `hashimpact.io` -> `hashimpact_frontend:8081`
- `api.hashimpact.io` -> `hashimpact_backend:8080`

## One-time setup

Make sure the shared Docker network exists:

```bash
docker network create hashtax_network
```

If it already exists, Docker will say so and you can ignore it.

## Run apps

Start the app containers first:

```bash
cd /home/czm016/projects/hashtax/hashtax_tools_fe
docker compose up -d --build
```

```bash
cd /home/czm016/projects/hashtax/hashtax_be
docker compose up -d --build
```

```bash
cd /home/czm016/projects/hashtax/HashImpact
docker compose up -d --build
```

## Run gateway

Only one nginx can bind `80/443`, so stop the old per-project nginx container if it is still running:

```bash
docker stop nginx_proxy
```

Then start the shared gateway:

```bash
cd /home/czm016/projects/hashtax/nginx_gateway
docker compose up -d
```

The old `hashtax_be` nginx service has been removed from its compose file. This gateway is now the only nginx container for public traffic.

Configs are separated under `conf.d`:

- `tools.conf` handles existing Hashtax tools domains.
- `hashimpact.conf` is the active HTTPS-ready HashImpact config.
- `hashimpact.http.conf.disabled` is the temporary HTTP-only config used while issuing certs.
- `hashimpact.ssl.conf.disabled` is the HTTPS template activated by `issue_hashimpact_ssl.sh`.

## Verify

```bash
docker compose ps
docker logs nginx_gateway --tail 100
```

Then check:

```bash
curl -I https://tools.hashtax.io
curl -I https://hashimpact.io
curl https://api.hashimpact.io/health
```

## SSL

The gateway mounts:

- `/etc/letsencrypt`
- `/var/www/certbot`

Certificates must exist for `tools.hashtax.io` and `hashimpact.io` before HTTPS server blocks can load.

Issue or renew HashImpact certs from this folder. The script activates HTTPS after certbot succeeds:

```bash
cd /home/czm016/projects/hashtax/nginx_gateway
bash issue_hashimpact_ssl.sh hello@hashtax.io
```

Manual command:

```bash
cd /home/czm016/projects/hashtax/nginx_gateway
docker compose --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d hashimpact.io \
  -d api.hashimpact.io \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  --non-interactive
```

Issue or renew tools certs from this folder:

```bash
cd /home/czm016/projects/hashtax/nginx_gateway
docker compose --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d tools.hashtax.io \
  -d tools-api.hashtax.io \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  --non-interactive
```

Reload the gateway after certificate changes:

```bash
docker compose restart nginx_gateway
```
