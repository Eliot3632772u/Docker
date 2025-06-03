FROM debian:bullseye

# Install dependencies
RUN apt update && apt install -y \
    gnupg2 curl ca-certificates lsb-release apt-transport-https

# Add Ondřej Surý's PHP PPA for Debian
RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/php.list


# Install PHP 8.3 and required extensions
RUN apt update && apt install -y \
    php8.3-fpm php8.3-common php8.3-mysql \
    php8.3-xml php8.3-intl php8.3-curl php8.3-gd \
    php8.3-imagick php8.3-cli php8.3-dev php8.3-imap \
    php8.3-mbstring php8.3-opcache php8.3-redis \
    php8.3-soap php8.3-zip

# Clean up
RUN apt clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/php

COPY tools/wordpress.sh /usr/local/bin/wordpress.sh

COPY config/www.conf /etc/php/8.3/fpm/pool.d/www.conf 

RUN chmod +x /usr/local/bin/wordpress.sh

CMD ["wordpress.sh"]