ARG PHP_VERSION=7.4
ARG PHANTOMJS_VERSION=2.1.1
ARG NODE_VERSION=18

# PhantomJS
FROM docker.io/library/alpine AS phantomjs

ARG PHANTOMJS_VERSION

WORKDIR /tmp

RUN apk add --no-cache wget && \
    wget -qO- https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2 | tar xvjf - && \
    mv phantomjs-${PHANTOMJS_VERSION}-linux-x86_64 phantomjs

# Yarn
FROM docker.io/library/node:${NODE_VERSION}-alpine AS yarn-install

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn install --production \
    && rm -rf /root/.cache/yarn

# PHP BASE
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

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /app

COPY composer.json composer.lock ./
#COPY ./app/ ./app 
#COPY ./infra/ ./infra
#COPY ./servicos/ ./servicos

RUN composer install --no-dev --no-scripts --no-interaction --optimize-autoloader \
    && rm -rf /root/.composer/cache/*

RUN openssl genrsa -out private.key 2048 \
    && openssl rsa -in private.key -pubout -out public.key

## Release
FROM php-base AS php-release

COPY --from=php-build-ext /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=php-build-ext /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=php-build-ext /app/vendor ./vendor
COPY --from=php-build-ext /app/private.key ./private.key
COPY --from=php-build-ext /app/public.key ./public.key
COPY --from=yarn-install /app/node_modules ./node_modules

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
    sqlsrv pdo_sqlsrv redis imagick mcrypt
# apt-get --purge autoremove autoconf gcc make

## Configs
COPY dockerfiles/apache2.conf "$APACHE_CONFDIR/conf-enabled/apache2.conf"
COPY dockerfiles/ports.conf "$APACHE_CONFDIR/ports.conf"
COPY dockerfiles/000-default.conf "$APACHE_CONFDIR/sites-enabled/000-default.conf"
COPY dockerfiles/security.conf "$APACHE_CONFDIR/sites-enabled/security.conf"
COPY dockerfiles/ssl.conf "$APACHE_CONFDIR/mods-available/ssl.conf"

HEALTHCHECK CMD curl --fail http://localhost/index.php || exit 1

RUN mkdir -p /var/www/html/apache2
ENV SESSION_HANDLER=files \
    SESSION_PATH=/var/www/html/empresas/session \
    DBDRIVE=mysql \
    APACHE_PORT=80 \
    CLIENTE_EXTERNO=0 \
    OPCACHE=0 \
    PROD=0 \ 
    APACHE_LOG_DIR=/var/www/html/apache2 \ 
    APACHE_LOCK_DIR=/var/www/html/apache2 \ 
    APACHE_PID_FILE=/var/www/html/apache2/apache2.pid \ 
    APACHE_RUN_DIR=/var/www/html/apache2 \ 
    APACHE_RUN_USER=www-data \ 
    APACHE_RUN_GROUP=www-data

## img final prod
FROM php-release AS production
ADD dockerfiles/php.ini-production "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

COPY . .

ENV CLIENTE_EXTERNO=1 \
    PROD=1

RUN chown -R www-data:www-data /var/www/html \
    && chmod -R g+rw /var/www/html

RUN ln -sf /dev/stdout /var/www/html/apache2/access.log \
    && ln -sf /dev/stderr /var/www/html/apache2/error.log

USER www-data
