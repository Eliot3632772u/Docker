FROM debian:bullseye

RUN apt update -y && apt upgrade -y &&  apt install php-redis curl php php-fpm php-mysql default-mysql-client -y

COPY tools/wordpress.sh /tmp/wordpress.sh

COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf

RUN chmod +x /tmp/wordpress.sh

CMD ["/tmp/wordpress.sh"]