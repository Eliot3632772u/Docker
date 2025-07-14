#!/bin/bash

mkdir -p /run/php

cd /var/www/html

if [ ! -f /usr/local/bin/wp ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

if [ ! -f wp-config.php ]; then
    wp core download --allow-root

    mv wp-config-sample.php wp-config.php
    sed -i "s|database_name_here|${MYSQL_DATABASE}|" wp-config.php
    sed -i "s|username_here|${MYSQL_USER}|" wp-config.php
    sed -i "s|password_here|${MYSQL_PASSWORD}|" wp-config.php
    sed -i "s|localhost|mariadb|" wp-config.php
    sed -i "/Add any custom values/a define('WP_REDIS_HOST', 'redis');" wp-config.php

fi



echo "Waiting for MariaDB to be ready..."

sleep 10

echo "✅ MariaDB is up"

if ! wp core is-installed --allow-root; then

    wp core install \
        --url="${DOMAIN_NAME}" \
        --title="${SITE_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=editor \
        --allow-root
fi

if ! wp plugin is-installed redis-cache --allow-root; then
    echo "📦 Installing Redis Object Cache plugin..."
    wp plugin install redis-cache --activate --allow-root
else
    echo "✅ Redis plugin already installed."
    wp plugin activate redis-cache --allow-root
fi

wp redis enable --allow-root

echo "Starting PHP-FPM..."
php-fpm7.4 -F
