# Imagem base para o PhantomJS
FROM php:alpine AS cacert

RUN apk add --no-cache wget \
    && wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
    && tar xvjf phantomjs-2.1.1-linux-x86_64.tar.bz2 -C /usr/local/share/ \
    && rm phantomjs-2.1.1-linux-x86_64.tar.bz2 \
    && ls /usr/local/share/

# Imagem base para o PHP com Apache
FROM php:7.2-apache

ENV ACCEPT_EULA=Y

# Atualização e instalação de dependências
RUN apt-get update && apt-get install -y \
    file \
    ghostscript \
    git \
    ca-certificates \
    gnupg \
    apt-transport-https \
    libmcrypt-dev \
    libfontconfig1-dev \
    libcurl4-gnutls-dev \
    libxml2-dev \
    libmagickwand-dev \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Configuração do Node.js
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs

# Instalação dos drivers do SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/9/prod.list \
    > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get install -y --no-install-recommends \
    locales \
    apt-transport-https \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
    unixodbc-dev \
    msodbcsql17

RUN docker-php-ext-install mbstring pdo pdo_mysql zip
RUN pecl install sqlsrv-5.8.0
RUN pecl install pdo_sqlsrv-5.8.0

# Configurações do PhantomJS
COPY --from=cacert /usr/local/share/phantomjs-2.1.1-linux-x86_64/ /usr/local/share/phantomjs/
RUN ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin

ADD docker/php7.conf/xdebug.ini "$PHP_INI_DIR/conf.d/xdebug.ini"
RUN pecl install xdebug-3.0.4
ADD docker/php7.conf/apache2.conf "$APACHE_CONFDIR/conf-enabled/apache2.conf"

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN npm install --global yarn

WORKDIR /var/www/html/

ADD ./ /var/www/html/.

RUN composer install --no-dev
RUN composer dumpautoload -o
RUN yarn install

RUN mkdir empresas/ \
    && chmod -Rf 0777 /var/www/html/

ADD docker/php7.conf/php.ini-production "$PHP_INI_DIR/php.ini"
RUN sed 's:SUPORTE_CONTAINER_CLIENTE = \[\]:SUPORTE_CONTAINER_CLIENTE = ["spu_GabrielDuarte","spu_JulioCezar","spu_MarjoryMuller"]:g'  -i /var/www/html/config.php