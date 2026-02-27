# Chamilo LMS Docker Compose Setup

A Docker Compose configuration for [Chamilo](https://chamilo.org/) LMS 2.0+.

This setup provides a complete, production-ready Docker environment for Chamilo with automatic database initialization and proper permission handling.

## Official Images Used

* [php](https://hub.docker.com/_/php/) (8.2+ apache)
* [mariadb](https://hub.docker.com/_/mariadb/) (11.4)

**Chamilo LMS Repository:** https://github.com/chamilo/chamilo-lms
**Official Installation Guide:** https://2.chamilo.org/documentation/installation_guide.html

## System Requirements

This Docker setup meets the official Chamilo 2.0+ requirements:

### Server

* Apache 2.4+ (with mod-rewrite enabled)
* MariaDB 10+ or MySQL 5+
* PHP 8.2+ (8.3+ included in this setup)

### Docker Host Requirements

* Docker & Docker Compose 3.8+
* 2GB+ available RAM (4GB+ recommended for production)
* Linux/macOS (Windows with WSL2)

### Included PHP Extensions

All required extensions for Chamilo are pre-installed:

* apcu (optional but recommended)
* bcmath
* curl
* exif
* gd
* iconv
* intl
* json
* ldap
* mbstring
* mysql
* opcache
* pcre
* redis (optional, for session management)
* soap
* sodium
* xml
* xsl
* zip
* zlib

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/webstone/docker-compose-chamilo-lms.git
cd docker-compose-chamilo-lms
```

### 2. Configure Environment Variables

Copy and edit the environment configuration:

```bash
cp .env.example .env
```

Update `.env` with your settings (database credentials, ports, etc.):

```
COMPOSE_PROJECT_NAME=chamilo2
DOCKER_NETWORK=chamilo2-network
CHAMILO_PORT=8080
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_USER=chamilo2
MYSQL_PASSWORD=your_secure_password
MYSQL_DATABASE=chamilo2
APP_ENV=dev
```

**Important for Production:** Change all default passwords and set `APP_ENV=prod`.

### 3. Configure Host File (Optional but Recommended)

Add to your `/etc/hosts` file:

```bash
echo "127.0.0.1 docker.chamilo.net" | sudo tee -a /etc/hosts
```

On Windows, edit `C:\Windows\System32\Drivers\etc\hosts` as Administrator and add:

```
127.0.0.1 docker.chamilo.net
```

### 4. Build and Start Containers

```bash
docker-compose build
docker-compose up -d
```

Verify containers are running:

```bash
docker-compose ps
```

### 5. Access Chamilo Installation Wizard

Open your browser:

* With hosts entry: http://docker.chamilo.net:8080/
* Without hosts entry: http://localhost:8080/

The Chamilo installation wizard will guide you through the setup process. Keep your database credentials at hand.

## Post-Installation

### Important: Clean Up (in production)

After successful installation via the wizard, run:

```bash
docker-compose exec chamilo bash
rm -rf public/main/install/
exit
```

This removes the installation directory for security reasons.

### Permissions After Installation (in production)

For security, tighten permissions on sensitive files:

```bash
docker-compose exec chamilo bash -c "chown root: config/ .env && chmod 644 .env"
```

Note: The `var/` directory must remain writable by the web server for cache and uploads.

## Configuration

### Environment Variables

All configuration is managed through `.env`. Key variables:

* `CHAMILO_PORT` - Port to access Chamilo (default: 8080)
* `MARIADB_PORT` - Database port (default: 3306)
* `APP_ENV` - Environment (dev/prod, default: dev)
* `APP_DEBUG` - Debug mode (default: 1 for dev, 0 for prod)
* `MYSQL_DATABASE` - Database name
* `MYSQL_USER` - Database user
* `MYSQL_PASSWORD` - Database password
* `DOCKER_NETWORK` - Docker network name

### Redis Configuration (Optional)

To enable Redis for session management, uncomment these lines in `chamilo2-php8/files/chamilo.conf`:

```apache
php_admin_value session.save_handler "redis"
php_admin_value session.save_path "tcp://redis:6379"
```

Then add a Redis service to `docker-compose.yml` (not included by default).

### PHP Settings

Default PHP settings are configured in the vhost:

* `upload_max_filesize = 256M`
* `post_max_size = 256M`
* `memory_limit = 512M` (during build)
* `session.cookie_httponly = 1`
* `opcache.enable = 1`

## Development

### Edit Source Files

Source files are mounted from your host directory. You can edit files directly in your IDE:

```bash
nano /srv/docker/chamilo2/htdocs/app/Http/Controller/HomeController.php
```

Changes take effect immediately without rebuilding.

### Access Container Shell

```bash
docker-compose exec chamilo bash
```

### Run Symfony Commands

```bash
docker-compose exec chamilo console about
docker-compose exec chamilo console cache:clear
docker-compose exec chamilo console doctrine:query:sql "SELECT VERSION()"
```

### View Logs

```bash
docker-compose logs -f chamilo
docker-compose logs -f mariadb
```

## File Permissions

### During Development

Files are editable from your host machine. The web server runs as `www-data` and has group write access to:

* `config/` - Configuration
* `public/` - Web accessible files
* `var/` - Cache, logs

### After Installation

Change permissions on sensitive files:

```bash
docker-compose exec chamilo bash -c "chown root: config/ && chmod 750 config/"
docker-compose exec chamilo bash -c "chown root: .env && chmod 640 .env"
```

## Common Tasks

### Stop Containers

```bash
docker-compose down
```

### Stop and Remove All Data

```bash
docker-compose down -v
```

### Clear Cache

```bash
docker-compose exec chamilo rm -rf var/cache/*
```

### Backup Database

```bash
docker-compose exec mariadb mysqldump -u chamilo2 -p chamilo2 > backup.sql
```

### Restore Database

```bash
docker-compose exec -T mariadb mysql -u chamilo2 -p chamilo2 < backup.sql
```

## Troubleshooting

**Database Connection Fails**

Check MariaDB is healthy:

```bash
docker-compose ps
docker-compose logs mariadb
```

Verify DATABASE_URL in container:

```bash
docker-compose exec chamilo env | grep DATABASE_URL
```

**Permission Denied Errors**

Check file ownership:

```bash
docker-compose exec chamilo ls -la var/ config/ .env
```

Reset permissions:

```bash
docker-compose restart chamilo
```

**Port Already in Use**

Change ports in `.env`:

```
CHAMILO_PORT=8081
MARIADB_PORT=13306
```

Then rebuild:

```bash
docker-compose down
docker-compose up -d
```

**Installation Wizard Not Appearing**

The wizard appears only if `.env` is missing or incomplete. Verify:

```bash
docker-compose exec chamilo ls -la .env
docker-compose exec chamilo cat .env
```

**Slow Performance**

Increase Docker memory allocation and enable Redis for sessions (see Configuration section).

## Production Deployment

### Important Steps

1. Change all default credentials in `.env`
2. Set `APP_ENV=prod` and `APP_DEBUG=0`
3. Use proper database passwords (min 12 chars with special characters)
4. Set up HTTPS with a reverse proxy (nginx, Apache)
5. Configure proper firewall rules
6. Set up automated backups for the database
7. Remove the installation wizard directory
8. Use secrets management for sensitive values
9. Configure proper logging and monitoring
10. Consider using a separate Redis container for session management

### Docker Compose Production Example

Use a separate `docker-compose.prod.yml` file with:

* Restricted restart policies
* Resource limits
* Health checks
* Proper logging drivers
* Named volumes for persistence

## Documentation

* Docker Compose Documentation: https://docs.docker.com/compose/
* Chamilo 1 Official Docs: https://docs.chamilo.org/
* Chamilo 2 Installation Guide: https://2.chamilo.org/documentation/installation_guide.html

## Support

If you encounter issues:

1. Check the official [Chamilo forum](https://chamilo.org/forum)
2. Review [Chamilo documentation](https://docs.chamilo.org)
3. Check Docker logs: `docker-compose logs chamilo`

## License

This Docker Compose configuration is provided as-is for Chamilo deployment.

Chamilo is licensed under GNU General Public License v3.0 (GPLv3).