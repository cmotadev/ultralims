# Estágio 1: Base para PhantomJS e Certificados
# FROM php:8.2-alpine AS cacert

# RUN apk add --no-cache wget \
#    && wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
#    && tar xvjf phantomjs-2.1.1-linux-x86_64.tar.bz2 -C /usr/local/share/ \
#    && ln -sf /usr/local/share/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs \
#    && rm -rf phantomjs-2.1.1-linux-x86_64.tar.bz2


FROM php:7.4-apache AS php-base

ENV ACCEPT_EULA=Y

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
   gnupg2 curl apt-transport-https \
   && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
   && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
   && apt-get update \
   && ACCEPT_EULA=Y apt-get -y --no-install-recommends install \
   msodbcsql17 unixodbc-dev \
   libmcrypt-dev libfontconfig1-dev libgd-dev libfreetype6-dev libjpeg62-turbo-dev \
   libcurl4-gnutls-dev libxml2-dev libzip-dev libonig-dev libmagickwand-dev \
   file ghostscript git

RUN pecl install mcrypt-1.0.5 imagick redis sqlsrv-5.10.0 pdo_sqlsrv-5.10.0 \
   && docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg=/usr/local/lib \
   && docker-php-ext-install gd curl xml zip mbstring mysqli pdo pdo_mysql fileinfo intl bcmath opcache \
   && docker-php-ext-enable mysqli pdo pdo_mysql mcrypt gd curl xml zip fileinfo mbstring intl bcmath sqlsrv pdo_sqlsrv redis imagick \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/* /tmp/pear /usr/local/src/* /usr/share/man /usr/share/doc /usr/share/doc-base \
   && find /var/cache -type f -exec rm -rf {} \; \
   && find /var/log -type f -exec rm -rf {} \;

# ## Configs
# ADD docker/php7.conf/php.ini-development "$PHP_INI_DIR/php.ini"
# ADD docker/php7.conf/apache2.conf "$APACHE_CONFDIR/conf-enabled/apache2.conf"
# ADD docker/php7.conf/xdebug.ini "$PHP_INI_DIR/conf.d/xdebug.ini"
# ADD docker/php7.conf/ports.conf "$APACHE_CONFDIR/ports.conf"
# ADD docker/php7.conf/000-default.conf "$APACHE_CONFDIR/sites-enabled/000-default.conf"
# ADD docker/php7.conf/security.conf "$APACHE_CONFDIR/sites-enabled/security.conf"
# ADD docker/php7.conf/ssl.conf "$APACHE_CONFDIR/mods-available/ssl.conf"

# COPY --from=cacert /usr/local/share/phantomjs-2.1.1-linux-x86_64/ /usr/local/share/phantomjs/

# RUN ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin

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


# FROM php-base AS composer-install

# COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# WORKDIR /app

# COPY composer.json composer.lock ./

# ADD ./app/ ./app
# ADD ./infra/ ./infra
# ADD ./servicos/ ./servicos

# RUN composer install --no-dev --no-scripts --no-interaction --optimize-autoloader \
#    && rm -rf /root/.composer/cache/*

# RUN openssl genrsa -out private.key 2048 \
#    && openssl rsa -in private.key -pubout -out public.key   


# # Estágio 4: Instalação do Yarn
# FROM node:18-alpine AS yarn-install

# WORKDIR /app

# COPY package.json yarn.lock ./

# RUN yarn install --production \
#    && rm -rf /root/.cache/yarn

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
