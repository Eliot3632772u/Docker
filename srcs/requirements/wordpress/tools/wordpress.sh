mkdir -p /var/www/wordpress
cd /var/www/wordpress

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

wp core download --allow-root

wp config create \
  --dbname=${MYSQL_DATABASE} \
  --dbuser=${MYSQL_USER} \
  --dbpass=${MYSQL_PASSWORD} \
  --dbhost=mariadb \
  --config-file=/var/www/wordpress/wp-config.php \
  --allow-root

wp core install \
  --url="${DOMAIN_NAME}" \
  --title="${SITE_TITLE}" \
  --admin_user="${WP_ADMIN_USER}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --allow-root

wp user create \
   "${WP_USER}" "${WP_USER_EMAIL}" \
   --user_pass="${WP_USER_PASSWORD}" \
   --role=editor \
   --allow-root

mkdir -p /run/php

php-fpm7.4 -F