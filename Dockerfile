FROM php:7.3-fpm
MAINTAINER Meritoo <github@meritoo.pl>

#
# Required to avoid bug/problems while installing Yarn:
# a) related to https repositories
#    E: The method driver /usr/lib/apt/methods/https could not be found.
# b) missing library "gnupg"
#    E: gnupg, gnupg2 and gnupg1 do not seem to be installed, but one of them is required for this operation
#    curl: (23) Failed writing body (517 != 1369)
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        gnupg

#
# Yarn (https://yarnpkg.com)
#
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends yarn

#
# Node.js
#
# More:
# https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
#
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y nodejs

#
# Tools & libraries
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends --fix-missing \
        libpng-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libxpm-dev \
        libwebp-dev \
        vim \
        git \
        unzip \
        openssl \
        libzip-dev \
        libmagickwand-dev \
        locales \
        ssh \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

#
# Generating locales:
# - de_DE
# - es_ES
# - en_GB
# - en_US
# - fr_FR
# - it_IT
# - pl_PL
# - ru_RU
#
RUN sed -i 's/^# de_DE/de_DE/g; \
            s/^# es_ES/es_ES/g; \
            s/^# en_GB/en_GB/g; \
            s/^# en_US/en_US/g; \
            s/^# fr_FR/fr_FR/g; \
            s/^# it_IT/it_IT/g; \
            s/^# pl_PL/pl_PL/g; \
            s/^# ru_RU/ru_RU/g;' /etc/locale.gen \
    && locale-gen

#
# Configure PHP extensions
#
RUN docker-php-ext-configure \
    gd \
    --with-freetype-dir=/usr/include/ \
    --with-jpeg-dir=/usr/include/ \
    --with-xpm-dir=/usr/include/ \
    --with-webp-dir=/usr/include/

#
# PHP extensions
#
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    opcache \
    intl \
    zip \
    gd

#
# PHP extensions (PECL):
# - Xdebug
# - Imagick
# - APCu
#
RUN pecl install \
        xdebug \
        imagick \
        apcu \
    && docker-php-ext-enable \
        xdebug \
        imagick \
        opcache \
        apcu \
        intl \
        zip \
        gd

COPY xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

#
# PHP configuration:
# - default configuration
# - timezone
#
COPY php.ini /usr/local/etc/php/php.ini
ARG TIMEZONE
RUN ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo ${TIMEZONE} > /etc/timezone \
    && printf '[PHP]\ndate.timezone = "%s"\n', ${TIMEZONE} > /usr/local/etc/php/conf.d/tzone.ini \
    && "date"
#RUN echo "\n""date.timezone = $TIMEZONE""\n" >> /usr/local/etc/php/php.ini

#
# Phing
#
RUN pear channel-discover pear.phing.info \
    && pear install [--alldeps] phing/phing

#
# Composer - environment variables:
# - disable warning about running commands as root/super user
# - disable automatic clearing of sudo sessions
#
# More:
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
#
ENV COMPOSER_ALLOW_SUPERUSER 1

#
# Composer + https://packagist.org/packages/hirak/prestissimo package
#
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('SHA384', 'composer-setup.php') === \
        '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5') { echo \
        'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');" \
    && composer global require \
        --no-plugins \
        --no-scripts \
        --no-progress \
        --no-suggest \
        --no-interaction \
        --prefer-dist \
        --optimize-autoloader \
        --classmap-authoritative \
        hirak/prestissimo \
    && rm -rf ~/.composer/cache/* \
    && composer clear-cache \
    && composer --version

#
# Bash
#
RUN sed -i 's/^# export/export/g; \
            s/^# alias/alias/g;' ~/.bashrc \
    && echo "\n"'alias sf="php bin/console"' >> ~/.bashrc \
    && echo 'COLUMNS=200'"\n" >> ~/.bashrc

#
# Use project-related binaries globally
#
ENV PATH="/var/www/application/vendor/bin:${PATH}"

WORKDIR /var/www/application
