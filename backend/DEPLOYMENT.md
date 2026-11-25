# FarmApp deployment runbook

## Scope

This runbook covers the Laravel API and CRM Docker stack. Deploy the main Flutter app first; buyer, driver, supplier, and veterinary app releases remain separate.

## Local development

Use the existing compose file:

```sh
docker compose -f backend/docker-compose.yml up --build
```

The local stack retains its HTTP-only Nginx configuration. Do not use it as the production entry point.

## Production startup

1. Provision the host, DNS, firewall, and a valid TLS certificate for the FarmApp domain.
2. Place the certificate chain at `backend/nginx/certs/fullchain.pem` and its private key at `backend/nginx/certs/privkey.pem`. Never commit either file.
3. Create `backend/app/.env` on the server from `.env.example`; do not commit it.
4. Set at minimum: `APP_ENV=production`, `APP_DEBUG=false`, the real HTTPS `APP_URL`, a generated `APP_KEY`, production database credentials, exact production CORS origins, a real mail transport, Firebase credentials, and the intended AWS region/storage configuration.
5. Set `QUEUE_CONNECTION=database`. The existing Laravel jobs migration creates `jobs`, `job_batches`, and `failed_jobs`.
6. Configure M-Pesa sandbox credentials and a public HTTPS callback URL for sandbox verification. Keep live credentials and live payments disabled until a separate production approval.
7. Start the production overlay:

```sh
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml config
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml up -d --build
```

The production overlay adds a persistent Laravel queue worker, Laravel scheduler process, and TLS listener. HTTP requests are redirected to HTTPS.

## Operational checks

```sh
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml ps
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml logs --tail=200 backend queue-worker scheduler nginx
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml exec backend php artisan queue:failed
docker compose -f backend/docker-compose.yml -f backend/docker-compose.production.yml exec backend php artisan schedule:list
```

Before promotion, verify TLS renewal, host-level firewall rules (only required ports exposed), database backups and restore procedure, persistent storage backups, queue failure alerts, application logs, and the health endpoint at `/up`.

## Important deployment safeguards

- Back up the database and persistent storage before migrations.
- Review migration impact before running the backend container; its startup command applies migrations automatically.
- Do not seed production data. The existing container command intentionally skips seeding when `APP_ENV=production`.
- Do not expose MySQL publicly.
- Do not store credentials, private keys, Firebase service-account files, or M-Pesa secrets in Git.
- Run CI and a staging deployment before production promotion. A green build alone is not production acceptance.
