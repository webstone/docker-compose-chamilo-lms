#!/bin/bash
set -e

# Create wrapper scripts in /usr/local/bin for direct access
cat > /usr/local/bin/console << 'CONSOLE'
#!/bin/bash
cd /var/www/chamilo
php bin/console "$@"
CONSOLE
chmod +x /usr/local/bin/console

cat > /usr/local/bin/phpunit << 'PHPUNIT'
#!/bin/bash
cd /var/www/chamilo
php bin/phpunit "$@"
PHPUNIT
chmod +x /usr/local/bin/phpunit

cat > /usr/local/bin/composer << 'COMPOSER'
#!/bin/bash
cd /var/www/chamilo
php /usr/bin/composer "$@"
COMPOSER
chmod +x /usr/local/bin/composer

# Create .htaccess for documentation if it doesn't exist
mkdir -p /var/www/chamilo/public/documentation
if [ ! -f /var/www/chamilo/public/documentation/.htaccess ]; then
  cat > /var/www/chamilo/public/documentation/.htaccess << 'EOF'
# Redirect /documentation/ to /documentation/index.html
DirectoryIndex index.html

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /documentation/

    # If request is a directory with trailing slash, redirect to index.html
    RewriteCond %{REQUEST_FILENAME} -d
    RewriteRule ^(.*)$ index.html [L]

    # If the requested file doesn't exist and it's not a directory
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^ index.html [L]
</IfModule>
EOF
fi

# Fix permissions on mounted volumes for development
# Step 1: Change group to www-data (keep owner unchanged)
chgrp -R www-data /var/www/chamilo/config 2>/dev/null || true
chgrp -R www-data /var/www/chamilo/var 2>/dev/null || true
chgrp www-data /var/www/chamilo/.env 2>/dev/null || true

# Step 2: Make directories group-writable and executable
find /var/www/chamilo/config -type d -exec chmod g+wx {} \; 2>/dev/null || true
find /var/www/chamilo/var -type d -exec chmod g+wx {} \; 2>/dev/null || true

# Step 3: Make files group-readable and writable (but NOT executable)
find /var/www/chamilo/config -type f -exec chmod g+rw {} \; 2>/dev/null || true
find /var/www/chamilo/var -type f -exec chmod g+rw {} \; 2>/dev/null || true

# Step 4: Make .env group-readable and writable
chmod g+rw /var/www/chamilo/.env 2>/dev/null || true

# Start Apache
exec apache2-foreground