#!/bin/ash
# Runs after the image's entrypoint has migrated and seeded the database,
# right before supervisord (nginx, PHP-FPM, queue worker, scheduler) starts.
cd /app
php /railway/bootstrap.php || echo "WARNING: the Railway bootstrap step failed; see the lines above." >&2
php artisan view:clear >/dev/null 2>&1 || true
# Steps above run as root; PHP-FPM and the workers run as nginx.
chown -R nginx:nginx "${PAYMENTER_DATA_DIR:-/data}/storage"
exec "$@"
