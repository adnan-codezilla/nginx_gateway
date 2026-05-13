# Shared Nginx Gateway

This gateway owns ports `80` and `443` for all projects on this server.

It routes traffic to 4 different containers:
- `tools.hashtax.io` -> `hashtax_frontend:3000`
- `tools-api.hashtax.io` -> `hashtax_backend:5000`
- `hashimpact.io` -> `hashimpact_frontend:8081`
- `api.hashimpact.io` -> `hashimpact_backend:8080`

## 1. Network Setup (One-time)
Make sure the shared Docker network exists before starting any app:
```bash
docker network create hashtax_network
```

## 2. Run Apps
Start the app containers from their respective folders:
```bash
cd /home/ec2-user/projects/hash_tax/hashtax_tools_fe
docker compose up -d --build

cd /home/ec2-user/projects/hash_tax/hashtax_be
docker compose up -d --build

cd /home/ec2-user/projects/hash_tax/HashImpact/website
docker compose up -d --build frontend

cd /home/ec2-user/projects/hash_tax/HashImpact/backend
docker compose up -d --build backend
```

HashImpact is split into service-owned compose files:
- `HashImpact/website/docker-compose.yml` owns `hashimpact_frontend`.
- `HashImpact/backend/docker-compose.yml` owns `hashimpact_backend`.
- Both services must stay attached to the external `hashtax_network` and keep these aliases, because the gateway routes to `hashimpact_frontend:8081` and `hashimpact_backend:8080`.

## 3. Run Gateway & SSL Setup
Go to this `nginx_gateway` folder:
```bash
cd /home/ec2-user/projects/hash_tax/nginx_gateway
```

Run the automated script to issue all SSL certificates. This script will:
1. Start Nginx in HTTP-only mode to pass the ACME challenges.
2. Use Certbot to fetch certificates for all domains.
3. Automatically activate the HTTPS `.ssl.conf.disabled` templates.
4. Reload Nginx.

```bash
bash issue_all_ssl.sh hello@hashtax.io
```

## 4. SSL Auto-Renewal (Cron Job)
To make sure your SSL certificates renew automatically, add this to your live server's cron jobs:

```bash
crontab -e
```
Add this line at the bottom to run the renewal check every day at 3 AM:
```text
0 3 * * * cd /home/ec2-user/projects/hash_tax/nginx_gateway && bash renew_ssl.sh >> /var/log/ssl_renew.log 2>&1
```

## Config Architecture
- `conf.d/hashimpact.conf` and `conf.d/tools.conf` are the active configs.
- `conf.d/*.http.conf.disabled` are HTTP-only templates used for first-time ACME challenges.
- `conf.d/*.ssl.conf.disabled` are the HTTPS templates that `issue_all_ssl.sh` automatically copies and activates.
- `00-resolver.conf` helps Nginx dynamically resolve container IPs when containers restart.
