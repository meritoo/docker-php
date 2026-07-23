FROM php:8.2-fpm
LABEL org.opencontainers.image.authors="Meritoo <github@meritoo.pl>"

#
# Download the official PHP extension installer tool
#
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

#
# Prepare scripts
#
COPY entrypoint.sh composer-install.sh /opt/docker/
RUN chmod 700 /opt/docker/*

#
# Install Yarn (https://yarnpkg.com)
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends yarn

#
# Install Node.js
#
# More:
# https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
#
RUN curl -sL https://deb.nodesource.com/setup_current.x | bash - \
    && apt-get install -y nodejs

#
# Install tools & libraries
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends --fix-missing \
        libzip-dev \
        libmagickwand-dev \
        libpng-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libxpm-dev \
        libwebp-dev \
        libkrb5-dev \
        vim \
        git \
        unzip \
        openssl \
        locales \
        ssh \
        wget \
        rsync \
        fontconfig \
        libxrender1 \
        xfonts-75dpi \
        xfonts-base \
    && wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_arm64.deb \
    && apt-get install -y ./wkhtmltox_0.12.6.1-3.bookworm_arm64.deb \
    && rm wkhtmltox_0.12.6.1-3.bookworm_arm64.deb \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

#
# Generate locales:
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
# Install PHP extensions
#
RUN install-php-extensions \
    pdo \
    pdo_mysql \
    opcache \
    intl \
    zip \
    gd \
    imap

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
        gd \
        imap

COPY xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

#
# PHP configuration:
# - default configuration
#
COPY php.ini /usr/local/etc/php/php.ini

#
# Phing
#
RUN pear channel-discover pear.phing.info \
    && pear install phing/phing

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
# Composer
#
RUN /opt/docker/composer-install.sh \
    && rm -rf ~/.composer/cache/* \
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
ENTRYPOINT ["/opt/docker/entrypoint.sh"]
CMD ["php-fpm"]
