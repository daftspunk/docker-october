FROM php:7.4-apache
LABEL maintainer="October CMS <hello@octobercms.com> (@octobercms)"

# Enables apache rewrite w/ security
RUN a2enmod rewrite expires && \
    sed -i 's/ServerTokens OS/ServerTokens ProductOnly/g' \
    /etc/apache2/conf-available/security.conf

# Installs dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libyaml-dev \
    libzip4 \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    git \
    cron \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

# Sets recommended PHP.ini settings (https://secure.php.net/manual/en/opcache.installation.php)
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'expose_php=off'; \
    } > /usr/local/etc/php/conf.d/php-recommended.ini

RUN pecl install apcu \
    && pecl install yaml-2.0.4 \
    && docker-php-ext-enable apcu yaml

# Sets user to www-data
RUN chown www-data:www-data /var/www
USER www-data

# Installs October CMS
WORKDIR /var/www
RUN curl -o octobercms-install.zip -X POST -SL http://octobercms.com/api/core/get?type=install && \
    mkdir octobercms-install && \
    unzip octobercms-install.zip -d octobercms-install && \
    mv -T /var/www/octobercms-install /var/www/html && \
    rm octobercms-install.zip

# Creates cron job for maintenance scripts
RUN (crontab -l; echo "* * * * * cd /var/www/html;/usr/local/bin/php artisan schedule:run 1>> /dev/null 2>&1") | crontab -

# Returns to root user
USER root

# Copies init scripts
# COPY docker-entrypoint.sh /entrypoint.sh

# Provides container inside image for data persistence
VOLUME ["/var/www/html"]

# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["apache2-foreground"]
CMD ["sh", "-c", "cron && apache2-foreground"]