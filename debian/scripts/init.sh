#!/bin/sh
set -e


in_log() {
        local type="$1"; shift
        printf '%s [%s] [Entrypoint]: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$type" "$*"
}

docker_process_init_files() {
    echo
    local f
    for f; do
        case "$f" in
        *.sh)
            # https://github.com/docker-library/postgres/issues/450#issuecomment-393167936
            # https://github.com/docker-library/postgres/pull/452
            if [ -x "$f" ]; then
                in_log INFO "$0: running $f"
                "$f"
            else
                in_log INFO "$0: sourcing $f"
                . "$f"
            fi
            ;;
        *) in_log INFO "$0: ignoring $f" ;;
        esac
        echo
    done
}

# Create directories if they don't exist
mkdir -p \
    /var/www/html/storage/app/public \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/public/uploads

# Set directory permissions without changing ownership
chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache \
    /var/www/html/public/uploads

# Clear and cache config in production
if [ "$APP_ENV" = "production" ]; then
    php artisan config:cache
    php artisan optimize
    php artisan package:discover
    php artisan migrate --force

    echo "Checking initialization status..."

    # If first IN run, it needs to be initialized
    echo "Checking initialization status..."
    IN_INIT=$(php artisan tinker --execute='echo Schema::hasTable("accounts") && !App\Models\Account::all()->first();')
    echo "IN_INIT value: $IN_INIT"

    if [ "$IN_INIT" = "1" ]; then
        echo "Running initialization scripts..."
        docker_process_init_files /docker-entrypoint-init.d/*
    fi

    echo "Production setup completed"
    echo "IN_INIT value: $IN_INIT"

fi

echo "Starting supervisord..."
# Start supervisord in the foreground
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf