ARG PHP_VERSION="8.2.30"
FROM php:${PHP_VERSION}-apache AS php8_apache_base

# Install system packages and PHP extensions dependencies
RUN apt-get update && apt-get install -yq --no-install-recommends \
    curl \
	git \
	unzip \
	wget \
    libcurl4-openssl-dev \
	libicu-dev \
	libxml2-dev \
	libxslt-dev \
	libzip-dev \
	libpng-dev \
	libjpeg62-turbo-dev \
	libfreetype6-dev \
	libwebp-dev \
	libxpm-dev \
    libldap2-dev \
	libonig-dev \
	msmtp \
	&& apt-get autoclean \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
    --with-jpeg=/usr/include/ \
    --with-freetype=/usr/include/ \
    --with-webp=/usr/include/ && \
    docker-php-ext-configure ldap \
    --with-libdir=lib/x86_64-linux-gnu

RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    curl \
    exif \
    gd \
    intl \
    ldap \
    mbstring \
    mysqli \
    opcache \
    pdo_mysql \
    soap \
    xml \
    xsl \
    zip

# Install PECL extensions (apcu, redis)
RUN pecl install apcu redis && \
    docker-php-ext-enable apcu redis

# Increase PHP memory limit for build / cache
RUN echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini

# Enable Apache modules
RUN a2enmod rewrite headers remoteip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

FROM php8_apache_base AS php8_apache_chamilo2

ARG CHAMILO_VERSION="2.0.0-RC.1"

# Download and extract Chamilo 2
RUN curl -fsSL "https://github.com/chamilo/chamilo-lms/archive/refs/tags/v${CHAMILO_VERSION}.tar.gz" \
    -o chamilo.tar.gz && \
    tar -zxf chamilo.tar.gz && \
    rm chamilo.tar.gz && \
    mv chamilo-* chamilo

WORKDIR /var/www/chamilo

# Install PHP dependencies with Composer
RUN composer install --optimize-autoloader --no-interaction

# Set proper permissions for Chamilo directories
RUN chown -R www-data:www-data /var/www/chamilo && \
    chmod 755 /var/www/chamilo && \
    chmod -R 775 /var/www/chamilo/config && \
    chmod -R 775 /var/www/chamilo/public && \
    chmod -R 775 /var/www/chamilo/var

# Remove unnecessary files
RUN rm -rf .git* tests docs

# Configure Apache
RUN a2dissite 000-default && rm -rf /etc/apache2/sites-enabled/000-default.conf
COPY files/security.conf /etc/apache2/conf-available/
COPY files/chamilo.conf /etc/apache2/sites-available/chamilo.conf
RUN a2ensite chamilo && a2enconf security

# Fix permissions on startup (entrypoint script)
COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EXPOSE 80
