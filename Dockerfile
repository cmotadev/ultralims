ARG PHP_VERSION=7.4
ARG PHANTOMJS_VERSION=2.1.1


# PhantomJS
FROM docker.io/library/alpine AS phantomjs

ARG PHANTOMJS_VERSION

WORKDIR /tmp

RUN apk add --no-cache wget && \
    wget -qO- https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2 | tar xvjf - && \
    mv phantomjs-${PHANTOMJS_VERSION}-linux-x86_64 phantomjs


# PHP comum para todos os stages
ARG PHP_VERSION

FROM docker.io/library/php:${PHP_VERSION}-apache-bullseye AS php-base

ENV ACCEPT_EULA=Y

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        gnupg2 \
        curl \
        apt-transport-https && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl -fsSL --output /etc/apt/sources.list.d/mssql-release.list \
        https://packages.microsoft.com/config/debian/11/prod.list && \
    # update with new SQL server repo data
    apt-get update

#  PhantomJS - Isso entra na produção?
COPY --from=phantomjs /tmp/phantomjs/ /usr/local/share/phantomjs/

RUN ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin

# https://groups.google.com/a/opencast.org/g/dev/c/0Ghsxe6Wvr0?pli=1
# https://github.com/wch/webshot/issues/90
ENV OPENSSL_CONF=/usr/lib/ssl/openssl.cnf


# Build das extensões
FROM php-base AS php-build-ext

# PHP Extensions
RUN apt-get install -y --no-install-recommends --no-install-suggests \
        libcurl4-gnutls-dev \
        # libgd-dev \
        libxml2-dev \
        libzip-dev \
        libonig-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev  \
        libpng-dev && \
    docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd curl xml zip mbstring mysqli pdo pdo_mysql fileinfo intl bcmath opcache && \
    docker-php-ext-enable  gd curl xml zip mbstring mysqli pdo pdo_mysql fileinfo intl bcmath opcache 

# PECL Extensions    
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        msodbcsql17 \
        unixodbc-dev \
        libmcrypt-dev \
        libmagickwand-dev && \
    # WARNING: channel "pecl.php.net" has updated its protocols, use "pecl channel-update pecl.php.net" to update
    pecl channel-update pecl.php.net && \
    pecl install \
        mcrypt-1.0.5 \
        imagick-3.7.0 \
        redis-6.0.2 \
        sqlsrv-5.10.0 \
        pdo_sqlsrv-5.10.0 && \
    docker-php-ext-enable sqlsrv pdo_sqlsrv redis imagick mcrypt


# Composer
COPY --from=docker.io/library/composer:2 /usr/bin/composer /usr/local/bin/composer

# # Instalação do código do backend
# WORKDIR /app

# COPY composer.json composer.lock ./

# ADD ./app/ ./app
# ADD ./infra/ ./infra
# ADD ./servicos/ ./servicos

# RUN composer install --no-dev --no-scripts --no-interaction --optimize-autoloader \
#    && rm -rf /root/.composer/cache/*

# RUN openssl genrsa -out private.key 2048 \
#    && openssl rsa -in private.key -pubout -out public.key 


# # Stage: Yarn
# FROM node:18-alpine AS yarn-install

# WORKDIR /app

# VOLUME [ "/root/.cache" ]

# COPY package.json yarn.lock ./

# RUN yarn install --production 


# Stage release do PHP, sem os headers
FROM php-base AS php-release

COPY --from=php-build-ext /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=php-build-ext /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

RUN apt-get install -y --no-install-recommends --no-install-suggests \
        file \
        ghostscript \
        # git \
        libfreetype6 \
        libjpeg62-turbo  \
        libmagickwand-6.q16-6 \
        # libmagickcore-6.q16-6-extra \
        libpng16-16 \
        libmcrypt4 \        
        msodbcsql17 \
        unixodbc \
        libzip4 && \
        # zlib1g && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-enable \
        gd curl xml zip mbstring mysqli pdo pdo_mysql fileinfo intl bcmath opcache \
        sqlsrv pdo_sqlsrv redis imagick mcrypt && \
    # apt-get --purge autoremove autoconf gcc make
    echo "<?php phpinfo(); ?>" > index.php



# ## Configs
# ADD docker/php7.conf/php.ini-development "$PHP_INI_DIR/php.ini"
# ADD docker/php7.conf/apache2.conf "$APACHE_CONFDIR/conf-enabled/apache2.conf"
# ADD docker/php7.conf/xdebug.ini "$PHP_INI_DIR/conf.d/xdebug.ini"
# ADD docker/php7.conf/ports.conf "$APACHE_CONFDIR/ports.conf"
# ADD docker/php7.conf/000-default.conf "$APACHE_CONFDIR/sites-enabled/000-default.conf"
# ADD docker/php7.conf/security.conf "$APACHE_CONFDIR/sites-enabled/security.conf"
# ADD docker/php7.conf/ssl.conf "$APACHE_CONFDIR/mods-available/ssl.conf"



# 

# HEALTHCHECK CMD curl --fail http://localhost/index.php || exit 1

# ENV SESSION_HANDLER=files
# ENV SESSION_PATH=/var/www/html/empresas/session
# ENV DBDRIVE=mysql
# ENV APACHE_PORT=80
# ENV CLIENTE_EXTERNO=0
# ENV OPCACHE=0
# ENV PROD=0
# ENV APACHE_LOG_DIR=/var/log/apache2
# ENV APACHE_LOCK_DIR=/var/lock/apache2
# ENV APACHE_PID_FILE=/var/run/apache2.pid
# ENV APACHE_RUN_DIR=/var/run/apache2
# ENV APACHE_RUN_USER=www-data
# ENV APACHE_RUN_GROUP=www-data





# FROM php-base AS production

# WORKDIR /var/www/html

# COPY . .

# COPY --from=composer-install /app/vendor ./vendor

# COPY --from=yarn-install /app/node_modules ./node_modules

# COPY --from=composer-install /app/private.key ./private.key

# COPY --from=composer-install /app/public.key ./public.key

# RUN mkdir -p empresas/ \
#    && chmod -R 0777 /var/www/html/empresas \
#    && chmod 777 public.key private.key

# ADD docker/php7.conf/php.ini-production "$PHP_INI_DIR/php.ini"

# ENV CLIENTE_EXTERNO=1

# ENV PROD=1


# FROM production AS sgb

# RUN mkdir -p /var/www/html/apache2

# ENV APACHE_LOG_DIR=/var/www/html/apache2

# ENV APACHE_LOCK_DIR=/var/www/html/apache2

# ENV APACHE_PID_FILE=/var/www/html/apache2/apache2.pid

# ENV APACHE_RUN_DIR=/var/www/html/apache2

# ENV APACHE_RUN_USER=www-data

# ENV APACHE_RUN_GROUP=www-data

# RUN chown -R www-data:www-data /var/www/html \
#   && chmod -R g+rw /var/www/html

# RUN ln -sf /dev/stdout /var/www/html/apache2/access.log \
#   && ln -sf /dev/stderr /var/www/html/apache2/error.log
  
# USER www-data
