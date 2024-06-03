#!/bin/sh
php artisan optimize

# Check if DB works, if not crash the app.
DB_READY=$(php artisan tinker --execute='echo app()->call("App\Utils\SystemHealth@dbCheck")["success"];')
if [ "$DB_READY" != "1" ]; then
    php artisan migrate:status # Print verbose error
    in_error "Error connecting to DB"
fi

php artisan migrate --force

vendor/bin/snappdf download

/usr/bin/supervisord -c "/etc/supervisor/supervisord.conf"
