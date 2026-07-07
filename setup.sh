#!/bin/bash
#===============================================================================
# Video Streaming Platform — Automated Server Setup Script
#=======================================================================
# Provisions a bare Ubuntu 24.04 server to run a Kwik.cx-style video hosting
# platform behind Cloudflare.
#
# Usage: bash setup.sh [options]
#   --domain DOMAIN        Video host domain (required)
#   --portal-domain DOM    Front-end portal domain (for CORS/referer)
#   --stream-secret KEY    64-char hex secret for token signing
#   --db-password PASS     MySQL database password
#   --email EMAIL          SSL cert email
#   --ssh-port PORT        SSH port (default: 22)
#   --skip-firewall        Skip firewall configuration
#   --help                 Show this help
#
# Example:
#   bash setup.sh \
#     --domain kwik.example.com \
#     --portal-domain anime.example.com \
#     --stream-secret "$(openssl rand -hex 32)" \
#     --db-password "$(openssl rand -hex 16)" \
#     --email admin@example.com
#
# WARNING: This script makes significant changes to your system.
# Run on a fresh Ubuntu 24.04 server only.
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================

DOMAIN=""
PORTAL_DOMAIN=""
STREAM_SECRET=""
DB_PASSWORD=""
EMAIL="admin@example.com"
SSH_PORT=22
SKIP_FIREWALL=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# Argument Parsing
#===============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)          DOMAIN="$2"; shift 2 ;;
        --portal-domain)   PORTAL_DOMAIN="$2"; shift 2 ;;
        --stream-secret)   STREAM_SECRET="$2"; shift 2 ;;
        --db-password)     DB_PASSWORD="$2"; shift 2 ;;
        --email)           EMAIL="$2"; shift 2 ;;
        --ssh-port)        SSH_PORT="$2"; shift 2 ;;
        --skip-firewall)   SKIP_FIREWALL=true; shift ;;
        --help)            grep "^#" "$0" | grep -v "^#!/" | sed 's/^#//'; exit 0 ;;
        *)                 log_error "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    log_error "--domain is required"
    exit 1
fi

if [ -z "$STREAM_SECRET" ]; then
    STREAM_SECRET=$(openssl rand -hex 32)
    log_warn "Generated stream secret: $STREAM_SECRET"
fi

if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -hex 16)
    log_warn "Generated database password: $DB_PASSWORD"
fi

log_info "=== Video Host Setup Configuration ==="
log_info "Domain:          $DOMAIN"
log_info "Portal Domain:   ${PORTAL_DOMAIN:-<not set>}"
log_info "Email:           $EMAIL"
log_info "SSH Port:        $SSH_PORT"
echo ""

#===============================================================================
# Phase 1: System Updates & Dependencies
#===============================================================================

setup_system_dependencies() {
    log_info "Phase 1: Installing system dependencies..."

    sudo apt update -qq
    sudo apt upgrade -y -qq

    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update -qq

    sudo apt install -y \
        nginx \
        php8.3-fpm php8.3-cli php8.3-common \
        php8.3-mysql php8.3-pdo php8.3-mbstring \
        php8.3-xml php8.3-curl php8.3-zip \
        php8.3-bcmath php8.3-gd php8.3-intl \
        php8.3-redis php8.3-opcache \
        mariadb-server \
        redis-server \
        composer \
        git unzip curl wget \
        ufw fail2ban htop nload \
        prometheus-node-exporter \
        certbot python3-certbot-nginx \
        ffmpeg rsync

    log_ok "System dependencies installed"
}

#===============================================================================
# Phase 2: Firewall & SSH Hardening
#===============================================================================

configure_firewall() {
    if [ "$SKIP_FIREWALL" = true ]; then
        log_warn "Skipping firewall configuration"
        return
    fi

    log_info "Phase 2: Configuring firewall..."

    CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
    CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

    if [ -z "$CF_IPV4" ] || [ -z "$CF_IPV6" ]; then
        log_error "Failed to retrieve Cloudflare IP ranges"
        exit 1
    fi

    sudo ufw --force disable
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    MY_IP=$(curl -s https://ifconfig.me 2>/dev/null || echo "")
    if [ -n "$MY_IP" ]; then
        sudo ufw allow from "$MY_IP" to any port "$SSH_PORT" proto tcp
        log_info "Allowed SSH access from: $MY_IP"
    else
        log_warn "Could not detect your IP. SSH on port $SSH_PORT allowed from anywhere."
        sudo ufw allow "$SSH_PORT/tcp"
    fi

    for ip in $CF_IPV4; do
        sudo ufw allow from "$ip" to any port 80 proto tcp
        sudo ufw allow from "$ip" to any port 443 proto tcp
    done
    for ip in $CF_IPV6; do
        sudo ufw allow from "$ip" to any port 80 proto tcp
        sudo ufw allow from "$ip" to any port 443 proto tcp
    done

    sudo ufw --force enable
    log_ok "Firewall configured — only Cloudflare IPs can reach web ports"
}

#===============================================================================
# Phase 3: Nginx Configuration
#===============================================================================

configure_nginx() {
    log_info "Phase 3: Configuring Nginx..."

    sudo rm -f /etc/nginx/sites-enabled/default

    sudo tee "/etc/nginx/sites-available/video-host" > /dev/null <<NGINXCONF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    root /var/www/video-host/public;
    index index.php index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

    access_log /var/log/nginx/video-host-access.log;
    error_log  /var/log/nginx/video-host-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \\.php\$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PHP_VALUE "upload_max_filesize=10G
            post_max_size=10G
            max_execution_time=7200
            max_input_time=7200
            memory_limit=512M";
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_read_timeout 7200;
    }

    location /protected-videos/ {
        internal;
        alias /var/www/video-host/storage/app/videos/;
        output_buffers 32 32k;
        postpone_output 1460;
        aio on;
        directio 4m;
        sendfile on;
        sendfile_max_chunk 1m;
        tcp_nopush on;
    }

    location /protected-hls/ {
        internal;
        alias /var/www/video-host/storage/app/hls/;
        add_header Access-Control-Allow-Origin "https://${PORTAL_DOMAIN}" always;
        expires 24h;
        add_header Cache-Control "public, immutable";
        output_buffers 16 16k;
        sendfile on;
        tcp_nopush on;
    }

    location ~ /(\\.env|\\.git|storage/app/public|bootstrap/cache) {
        deny all;
        return 404;
    }

    location /api/upload {
        client_max_body_size 10G;
        try_files \$uri /index.php?\$query_string;
    }

    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|webp|avif)\$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
NGINXCONF

    sudo ln -sf /etc/nginx/sites-available/video-host /etc/nginx/sites-enabled/
    sudo nginx -t || { log_error "Nginx configuration test failed"; exit 1; }
    sudo systemctl reload nginx
    log_ok "Nginx configured for $DOMAIN"
}

#===============================================================================
# Phase 4: SSL Certificate
#===============================================================================

setup_ssl() {
    log_info "Phase 4: Setting up SSL certificate..."
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
    sudo certbot renew --dry-run 2>/dev/null || true
    log_ok "SSL certificate obtained and configured"
}

#===============================================================================
# Phase 5: Database Setup
#===============================================================================

setup_database() {
    log_info "Phase 5: Configuring database..."

    sudo mysql --execute="
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        FLUSH PRIVILEGES;
    " 2>/dev/null || true

    sudo mysql -u root -p"$DB_PASSWORD" --execute="
        CREATE DATABASE IF NOT EXISTS video_host CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS 'video_host'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON video_host.* TO 'video_host'@'localhost';
        FLUSH PRIVILEGES;
    "

    sudo tee /etc/mysql/mariadb.conf.d/99-video-host.cnf > /dev/null <<MYSQLCONF
[mysqld]
innodb_buffer_pool_size = 4G
innodb_log_file_size = 512M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2
max_connections = 500
max_allowed_packet = 1G
wait_timeout = 300
MYSQLCONF

    sudo systemctl restart mariadb
    log_ok "Database configured"
}

#===============================================================================
# Phase 6: PHP Configuration
#===============================================================================

configure_php() {
    log_info "Phase 6: Configuring PHP..."

    sudo tee /etc/php/8.3/fpm/conf.d/99-video-host.ini > /dev/null <<PHPINI
upload_max_filesize = 10G
post_max_size = 10G
max_execution_time = 7200
max_input_time = 7200
memory_limit = 512M
date.timezone = UTC
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60
PHPINI

    sudo systemctl restart php8.3-fpm
    log_ok "PHP configured"
}

#===============================================================================
# Phase 7: Laravel Application Setup
#===============================================================================

setup_laravel() {
    log_info "Phase 7: Setting up Laravel application..."

    sudo mkdir -p /var/www/video-host
    sudo chown -R "$USER:$USER" /var/www/video-host

    cd /var/www/video-host
    composer create-project --prefer-dist laravel/laravel . --no-interaction
    composer require laravel/sanctum predis/predis --no-interaction

    mkdir -p storage/app/videos storage/app/hls storage/app/thumbnails storage/app/uploads bootstrap/cache

    cp .env.example .env
    sed -i "s/APP_NAME=Laravel/APP_NAME=VideoHost/" .env
    sed -i "s/APP_ENV=local/APP_ENV=production/" .env
    sed -i "s/APP_DEBUG=true/APP_DEBUG=false/" .env
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=video_host/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=video_host/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env

    cat >> .env <<ENVEOF

# Video Host Configuration
STREAM_SECRET=$STREAM_SECRET
VIDEO_STORAGE_PATH=storage/app/videos
ALLOWED_ORIGINS=${PORTAL_DOMAIN}
STREAM_TOKEN_TTL=3600
MAX_UPLOAD_SIZE=10737418240
DEFAULT_CRF=25
DEFAULT_AUDIO_BITRATE=96000
ENVEOF

    php artisan key:generate --force
    php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider" --force

    sudo chown -R www-data:www-data /var/www/video-host/storage /var/www/video-host/bootstrap/cache
    sudo chmod -R 755 /var/www/video-host/storage /var/www/video-host/bootstrap/cache

    log_ok "Laravel application configured"
}

#===============================================================================
# Phase 8: Redis
#===============================================================================

configure_redis() {
    log_info "Phase 8: Configuring Redis..."
    sudo sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
    echo "maxmemory 2gb" | sudo tee -a /etc/redis/redis.conf
    echo "maxmemory-policy allkeys-lru" | sudo tee -a /etc/redis/redis.conf
    sudo systemctl restart redis-server
    log_ok "Redis configured"
}

#===============================================================================
# Phase 9: Log Rotation
#===============================================================================

configure_logrotate() {
    log_info "Phase 9: Configuring log rotation..."
    sudo tee /etc/logrotate.d/video-host > /dev/null <<LOGROTATE
/var/log/nginx/video-host-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        systemctl reload nginx
    endscript
}
/var/www/video-host/storage/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data www-data
}
LOGROTATE
    log_ok "Log rotation configured"
}

#===============================================================================
# Phase 10: Monitoring
#===============================================================================

configure_monitoring() {
    log_info "Phase 10: Setting up monitoring..."
    sudo systemctl enable prometheus-node-exporter 2>/dev/null || true
    sudo systemctl start prometheus-node-exporter 2>/dev/null || true

    cat > /usr/local/bin/monitor-bandwidth <<'MONSCRIPT'
#!/bin/bash
INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5}')
echo "Interface: $INTERFACE"
echo "RX: $(cat /sys/class/net/$INTERFACE/statistics/rx_bytes | numfmt --to=iec 2>/dev/null || echo N/A)"
echo "TX: $(cat /sys/class/net/$INTERFACE/statistics/tx_bytes | numfmt --to=iec 2>/dev/null || echo N/A)"
MONSCRIPT
    chmod +x /usr/local/bin/monitor-bandwidth
    log_ok "Monitoring configured"
}

#===============================================================================
# Phase 11: Backups
#===============================================================================

setup_backups() {
    log_info "Phase 11: Setting up backups..."
    sudo mkdir -p /backups/database /backups/config

    cat > /usr/local/bin/backup.sh <<'BACKUPSCRIPT'
#!/bin/bash
BACKUP_DIR="/backups/database"
CONFIG_DIR="/backups/config"
RETENTION_DAYS=7
DB_NAME="video_host"
DB_USER="video_host"
DB_PASS="PLACEHOLDER"

mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql.gz"
tar czf "$CONFIG_DIR/configs-$(date +%Y%m%d).tar.gz" /etc/nginx/ /etc/php/ /etc/mysql/ /etc/redis/ /var/www/video-host/.env /etc/letsencrypt/ 2>/dev/null
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$CONFIG_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
echo "Backup completed: $(date)"
BACKUPSCRIPT

    sed -i "s/DB_PASS=\"PLACEHOLDER\"/DB_PASS=\"$DB_PASSWORD\"/" /usr/local/bin/backup.sh
    chmod +x /usr/local/bin/backup.sh
    echo "0 3 * * * root /usr/local/bin/backup.sh" | sudo tee /etc/cron.d/video-host-backup
    log_ok "Backups configured (daily at 3 AM)"
}

#===============================================================================
# Phase 12: Verification
#===============================================================================

verify_setup() {
    log_info "Phase 12: Verifying installation..."
    echo ""
    echo "============================================"
    echo "  Video Host Setup — Verification Report"
    echo "============================================"
    echo ""

    for svc in nginx php8.3-fpm mariadb redis-server; do
        systemctl is-active --quiet "$svc" 2>/dev/null && log_ok "$svc is running" || log_warn "$svc is NOT running"
    done

    sudo ufw status 2>/dev/null | grep -q "active" && log_ok "Firewall is active" || log_warn "Firewall is inactive"

    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        local expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" 2>/dev/null | cut -d= -f2)
        log_ok "SSL certificate exists, expires: $expiry"
    fi

    echo ""
    echo "============================================"
    echo "  Post-Setup Steps"
    echo "============================================"
    echo ""
    echo "1. Cloudflare: Add A record for $DOMAIN → server IP (proxied)"
    echo "2. Cloudflare: Set SSL/TLS to Full (Strict)"
    echo "3. Generate Cloudflare Origin CA cert → install on server"
    echo "4. Run: php artisan migrate"
    echo ""
    echo "Database password: $DB_PASSWORD"
    echo "Stream secret:     $STREAM_SECRET"
    echo "Domain:            $DOMAIN"
}

#===============================================================================
# Main
#===============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   Video Host Server Setup Script v2.0         ║"
    echo "║   Target: $DOMAIN        ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    read -p "Configure this server as a video host? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { log_info "Cancelled."; exit 0; }

    setup_system_dependencies
    configure_firewall
    configure_nginx
    setup_ssl
    setup_database
    configure_php
    setup_laravel
    configure_redis
    configure_logrotate
    configure_monitoring
    setup_backups
    verify_setup

    log_info "Setup complete! Configure Cloudflare → install Origin CA → migrate DB"
}

main "$@"
