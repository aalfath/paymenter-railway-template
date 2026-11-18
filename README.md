[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/paymenter-1?utm_medium=integration&utm_source=button&utm_campaign=paymenter)

# Paymenter on Railway

Railway template for [Paymenter](https://github.com/Paymenter/Paymenter), the open-source billing and webshop panel for hosting companies (MIT).

## What it deploys

| Service | Source | State |
|---|---|---|
| **Paymenter** | this repo: `Dockerfile` pins the official image `ghcr.io/paymenter/paymenter:v1.5.9@sha256:27471e07…` (nginx, PHP-FPM, queue worker, scheduler) plus the small wrapper in [`railway/`](railway/) | volume on `/data`: uploads, OAuth keys, logs, themes, extensions |
| **MariaDB** | official image `mariadb:12.3.3`, pinned by digest | volume on `/var/lib/mysql` |
| **Redis** | Railway Redis (password protected) | volume; cache, sessions, queue |

The public service listens on `$PORT` (8080) and answers the health check on `/healthz` (200 when MariaDB and Redis respond). Migrations run on every start.

## Variables

You fill in one value: **`ADMIN_EMAIL`**, the login of the first administrator. Everything else is set by the template:

| Variable | Value |
|---|---|
| `ADMIN_PASSWORD` | `${{secret(24,…)}}`: the first admin's password, generated per deploy. Read it in the Paymenter service's **Variables** tab |
| `APP_KEY` | `base64:${{secret(43,…)}}=`: Laravel encryption key, generated. Never change it after the first start: encrypted settings would become unreadable |
| `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | references to the MariaDB service |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` |
| `PORT` | `8080` |

The admin is created only while the database has no users, so changing `ADMIN_EMAIL` or `ADMIN_PASSWORD` later does nothing; change your password in Paymenter instead. On first start the wrapper also sets Paymenter's **App URL** to the service's Railway domain and trusts Railway's proxy (Admin → Settings → Security), so HTTPS links and uploads work.

Optional, set later in **Admin → Settings**: mail (SMTP), currencies, payment gateways (Stripe, PayPal, Mollie) and server extensions (Pterodactyl, Convoy, Virtfusion…). With a custom domain, update **App URL** there too.

## After deploying

1. Open the Paymenter service's URL and sign in at `/login` with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`. The admin panel is at `/admin`.
2. Change the password (account menu), then set your company name, currency and mail settings.
3. Enable a payment gateway and a server extension, then create categories and products.

## Updates

The Paymenter service builds from this repo. When the pinned version is bumped on `main`, Railway shows deployers an "update available" notice, and you choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Migrations run automatically on start; back up MariaDB before a major version.

Default themes and bundled extensions are refreshed from the image on every start (Paymenter's own behaviour). Set `PAYMENTER_SKIP_DEFAULT=true` on the service if you edited them in place.

## Local test

```sh
docker build -t paymenter-railway .
```

Run it with the variables above, a MariaDB 11+ and a Redis, and a volume on `/data`. Licence: this wrapper is MIT; Paymenter itself is MIT.
