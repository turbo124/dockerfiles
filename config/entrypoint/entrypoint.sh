#!/bin/sh

in_error() {
    in_log ERROR "$@" >&2
    exit 1
}

in_log() {
    local type="$1"
    shift
    printf '%s [%s] [Entrypoint]: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$type" "$*"
}

chown -R www-data:www-data /var/www
chmod 775 /var/www/storage/logs
chmod 775 /var/www/storage/framework
chmod 775 /var/www/storage/cache
chmod 775 /var/www/bootstrap/cache

php artisan optimize

# Check if DB works, if not crash the app.
DB_READY=$(php artisan tinker --execute='echo app()->call("App\Utils\SystemHealth@dbCheck")["success"];')
if [ "$DB_READY" != "1" ]; then
    php artisan migrate:status # Print verbose error
    in_error "Error connecting to DB"
fi

php artisan migrate --force

php artisan storage:link

vendor/bin/snappdf download

/usr/bin/supervisord -c "/etc/supervisor/supervisord.conf"
