# Changelog

Each entry is one update of this template. Breaking changes are listed first. Railway shows deployers an "update available" notice when a change lands on `main`; read the entry before you apply it.

## 1.5.9-railway.1 (2026-11-18)

- First release of this template: Paymenter **v1.5.9**, official image `ghcr.io/paymenter/paymenter:v1.5.9` pinned by digest `sha256:27471e077f4413f5f7c4e63656a8e7894892fc8c6885e5481f91e420bd37b63b`.
- MariaDB 12.3.3 (official image, pinned by digest) and Railway Redis, each on its own volume.
- All Paymenter state on one volume at `/data`: uploads, OAuth keys, logs, themes, extensions and the `.env` copy.
- First admin created from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`; app URL and Railway's proxy set on first start.
- `/healthz` health check (database and Redis), nginx on `$PORT`, Laravel scheduler run by supervisord with the service's variables.
