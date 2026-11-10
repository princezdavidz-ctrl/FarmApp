#!/bin/bash
# Automated backend deployment script for cPanel.
# Usage: BACKEND_DIR=/home/your-account/apps/farm-app/backend/app ./deploy-backend.sh

set -e

BACKEND_DIR="${BACKEND_DIR:-$HOME/apps/farm-app/backend/app}"
API_DOMAIN="${API_DOMAIN:-api.example.invalid}"
CRM_DOMAIN="${CRM_DOMAIN:-crm.example.invalid}"

echo "========================================="
echo "Farm App - Backend Deployment"
echo "========================================="
echo ""

# Check prerequisites
echo "[1/10] Checking prerequisites..."
php -v | head -n1
composer --version | head -n1
echo "✓ PHP and Composer available"
echo ""

# Navigate to backend
echo "[2/10] Navigating to backend directory..."
cd "$BACKEND_DIR"
echo "✓ Working directory: $(pwd)"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "[3/10] Creating .env file..."
    echo "ERROR: .env does not exist. Please create it manually with production credentials."
    echo "Use the production template in DEPLOYMENT.md and add credentials only on the server."
    exit 1
else
    echo "[3/10] Using existing .env file"
    echo "✓ .env found"
fi
echo ""

# Prevent Docker-only settings from reaching a cPanel deployment.
DB_HOST_VALUE=$(sed -n 's/^DB_HOST=//p' .env | tail -n1)
CACHE_STORE_VALUE=$(sed -n 's/^CACHE_STORE=//p' .env | tail -n1)
SESSION_DRIVER_VALUE=$(sed -n 's/^SESSION_DRIVER=//p' .env | tail -n1)

if [ "$DB_HOST_VALUE" = "mysql" ]; then
    echo "ERROR: DB_HOST=mysql is a Docker-only setting. Set DB_HOST=localhost (or the cPanel database host) in .env."
    exit 1
fi

if [ "$CACHE_STORE_VALUE" = "database" ] || [ -z "$CACHE_STORE_VALUE" ]; then
    echo "ERROR: CACHE_STORE must be file on cPanel. Set CACHE_STORE=file in .env."
    exit 1
fi

if [ "$SESSION_DRIVER_VALUE" = "database" ]; then
    echo "ERROR: SESSION_DRIVER=database requires a working database. Set SESSION_DRIVER=file on cPanel."
    exit 1
fi

# Clear caches that do not require a database connection. The database cache
# store cannot be cleared until the production DB settings have been verified.
echo "[4/10] Clearing stale Laravel caches..."
php artisan config:clear
php artisan route:clear
php artisan view:clear
echo "✓ Laravel caches cleared"
echo ""

# Install dependencies
echo "[5/10] Installing Composer dependencies..."
composer install --no-dev --optimize-autoloader
echo "✓ Dependencies installed"
echo ""

# Generate APP_KEY if not set
echo "[6/10] Checking APP_KEY..."
if grep -q "APP_KEY=$" .env; then
    echo "⚠ APP_KEY not set. Generating..."
    NEW_KEY=$(php -r 'echo base64_encode(random_bytes(32));')
    sed -i "s/APP_KEY=/APP_KEY=base64:$NEW_KEY/" .env
    echo "✓ APP_KEY generated: base64:$NEW_KEY"
else
    echo "✓ APP_KEY already set"
fi
echo ""

# Run migrations
echo "[7/10] Running database migrations..."
php artisan migrate --force
MIGRATION_STATUS=$(php artisan migrate:status --no-ansi)
printf '%s\n' "$MIGRATION_STATUS"
if printf '%s\n' "$MIGRATION_STATUS" | awk -F'|' '$2 ~ /No/ { pending = 1 } END { exit pending }'; then
    echo "✓ No pending migrations"
else
    echo "ERROR: Pending migrations remain after deployment."
    exit 1
fi
echo "✓ Migrations completed"
echo ""

# Set permissions
echo "[8/10] Setting permissions..."
chmod -R 775 storage bootstrap/cache
echo "✓ Permissions set for storage and cache"
echo ""

# Cache configuration
echo "[9/10] Caching configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
echo "✓ Configuration cached"
echo ""

# Test API health
echo "[10/10] Testing API health..."
HEALTH_CHECK=$(curl -s https://$API_DOMAIN/up || echo "FAILED")
if echo "$HEALTH_CHECK" | grep -q "Application up"; then
    echo "✓ API health check passed"
else
    echo "⚠ API health check failed. Verify domain and HTTPS configuration."
    echo "Response: $HEALTH_CHECK"
fi
echo ""

# Summary
echo "[11/11] Deployment complete!"
echo ""
echo "========================================="
echo "Next Steps:"
echo "========================================="
echo "1. Build CRM: VITE_API_BASE_URL=https://$API_DOMAIN/api/v1 npm run build"
echo "2. Upload dist/ to https://$CRM_DOMAIN/"
echo "3. Test API: curl https://$API_DOMAIN/up"
echo "4. Open browser: https://$CRM_DOMAIN/"
echo ""
echo "For detailed instructions, see DEPLOYMENT.md"
echo "========================================="
