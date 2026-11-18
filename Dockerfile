# Paymenter (nginx, PHP-FPM, queue worker and cron in one container, run by supervisord)
# Official image, pinned by version and digest. Bump both together and add a CHANGELOG.md entry.
FROM ghcr.io/paymenter/paymenter:v1.5.9@sha256:27471e077f4413f5f7c4e63656a8e7894892fc8c6885e5481f91e420bd37b63b

# Fixed settings for this template (a variable set on the service wins). They live here,
# not in start.sh, so `railway ssh` / artisan commands see them too.
ENV APP_ENV=production \
    APP_DEBUG=false \
    DB_CONNECTION=mariadb \
    DB_PORT=3306 \
    CACHE_STORE=redis \
    QUEUE_CONNECTION=redis \
    SESSION_DRIVER=redis \
    REDIS_CLIENT=phpredis \
    PAYMENTER_DATA_DIR=/data

COPY railway/ /railway/
# /healthz (Railway health check) is added to the image's nginx site.
# The image runs Laravel's scheduler from cron, which starts jobs without the service's
# environment variables (database, Redis). Run it under supervisord instead, so invoices,
# suspensions and reminders run with the same settings as the web app.
RUN chmod 755 /railway/start.sh /railway/post-init.sh \
    && sed -i 's#server_name _;#server_name _;\n    include /railway/nginx-healthz.conf;#' /etc/nginx/http.d/default.conf \
    && sed -i '/artisan schedule:run/d' /var/spool/cron/crontabs/root \
    && printf '\n[program:scheduler]\ncommand=/usr/local/bin/php /app/artisan schedule:work\nuser=nginx\nautostart=true\nautorestart=true\n' >> /etc/supervisord.conf

# start.sh prepares the /data volume and nginx, then hands over to the image's own
# entrypoint (migrations + seed), which runs post-init.sh (first admin, URL) and supervisord.
ENTRYPOINT ["/railway/start.sh"]
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
