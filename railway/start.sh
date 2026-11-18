#!/bin/ash
# Railway wrapper for the official Paymenter image.
# - keeps every piece of state on the single Railway volume mounted at /data
# - makes nginx listen on $PORT
# - fills in defaults, waits for MariaDB, then runs the image's own entrypoint
set -eu

PORT="${PORT:-80}"
DATA="${PAYMENTER_DATA_DIR:-/data}"

# Defaults (any variable set on the service wins).
export APP_ENV="${APP_ENV:-production}"
export APP_DEBUG="${APP_DEBUG:-false}"
export DB_CONNECTION="${DB_CONNECTION:-mariadb}"
export DB_PORT="${DB_PORT:-3306}"
export CACHE_STORE="${CACHE_STORE:-redis}"
export QUEUE_CONNECTION="${QUEUE_CONNECTION:-redis}"
export SESSION_DRIVER="${SESSION_DRIVER:-redis}"
export REDIS_CLIENT="${REDIS_CLIENT:-phpredis}"
if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

for v in APP_KEY DB_HOST DB_DATABASE DB_USERNAME DB_PASSWORD; do
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then
    echo "ERROR: $v is not set. The Railway template sets it; add it on the Paymenter service." >&2
    exit 1
  fi
done
if [ -z "${REDIS_URL:-}" ] && [ -z "${REDIS_HOST:-}" ]; then
  echo "ERROR: REDIS_URL is not set (cache, sessions and the queue need Redis)." >&2
  exit 1
fi

# ---- Persistent layout on the volume ------------------------------------------------
# /data/var/.env      APP_KEY copy written by the image's entrypoint
# /data/storage       Laravel storage: uploads, OAuth (Passport) keys, logs, caches
# /data/themes        themes (defaults renewed on every start by the image)
# /data/extensions    extensions (gateways, server modules) incl. ones you upload
mkdir -p "$DATA/var" "$DATA/storage" "$DATA/themes" "$DATA/extensions"
rm -rf "$DATA/lost+found"

# First start: seed storage from the image (keeps the expected folder tree).
if [ ! -f "$DATA/storage/.railway-seeded" ] && [ -d /app/storage ] && [ ! -L /app/storage ]; then
  cp -Rp /app/storage/. "$DATA/storage/"
  touch "$DATA/storage/.railway-seeded"
fi
mkdir -p "$DATA/storage/app/public" "$DATA/storage/app/private" "$DATA/storage/logs" \
  "$DATA/storage/framework/cache/data" "$DATA/storage/framework/sessions" \
  "$DATA/storage/framework/views" "$DATA/storage/framework/testing"

for d in var storage themes extensions; do
  target="/app/$d"
  if [ ! -L "$target" ]; then
    rm -rf "$target"
    ln -s "$DATA/$d" "$target"
  fi
done
chown -R nginx:nginx "$DATA/storage" "$DATA/themes" "$DATA/extensions"

# ---- nginx on Railway's port -------------------------------------------------------------
sed -i -E "s/listen (\[::\]:)?[0-9]+;/listen \1${PORT};/g" /etc/nginx/http.d/default.conf

# ---- Wait for MariaDB (private DNS and first-boot init can take a while) ---------------
i=0
until php -r 'try { new PDO(sprintf("mysql:host=%s;port=%d;dbname=%s", getenv("DB_HOST"), (int) getenv("DB_PORT"), getenv("DB_DATABASE")), getenv("DB_USERNAME"), getenv("DB_PASSWORD"), [PDO::ATTR_TIMEOUT => 3]); } catch (Throwable $e) { exit(1); }' 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 100 ]; then
    echo "ERROR: database not reachable after 5 minutes." >&2
    exit 1
  fi
  echo "Waiting for the database ($i)..."
  sleep 3
done

echo "Paymenter: public URL ${APP_URL:-unset}, listening on ${PORT}, data in ${DATA}"
cd /app
exec /bin/ash /app/.github/docker/entrypoint.sh /railway/post-init.sh "$@"
