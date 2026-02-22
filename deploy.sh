#!/bin/bash
set -e

# Configuration
APP_NAME="indie"

# Load deploy configuration from .deploy.config
if [ -f ".deploy.config" ]; then
    source .deploy.config
else
    echo "Error: .deploy.config file not found"
    echo "Please create .deploy.config with the following variables:"
    echo "  DEPLOY_USER"
    echo "  DEPLOY_HOST"
    echo "  DEPLOY_PATH"
    echo "  DATA_PATH"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    error "Must run from project root directory"
fi

# Parse arguments
ENVIRONMENT=${1:-production}

if [ "$ENVIRONMENT" != "production" ]; then
    error "Only 'production' environment is supported"
fi

info "Starting deployment to $ENVIRONMENT..."

# Step 1: Clean previous builds
info "Cleaning previous builds..."
rm -rf _build/prod/rel

# Step 2: Get dependencies
info "Fetching dependencies..."
mix deps.get --only prod

# Step 3: Compile assets
info "Compiling assets..."
MIX_ENV=prod mix assets.deploy

# Step 4: Build release
info "Building release..."
MIX_ENV=prod mix release --overwrite

# Step 5: Create tarball
info "Creating tarball..."
tar -czf _build/prod/rel/$APP_NAME/$APP_NAME.tar.gz -C _build/prod/rel/$APP_NAME --exclude='*.tar.gz' . 2>&1 | grep -v "file changed as we read it" || true
if [ ! -f "_build/prod/rel/$APP_NAME/$APP_NAME.tar.gz" ]; then
    error "Failed to create tarball"
fi

# Step 6: Upload release to server
info "Uploading release to server..."
scp _build/prod/rel/$APP_NAME/$APP_NAME.tar.gz $DEPLOY_USER@$DEPLOY_HOST:/tmp/

# Step 7: Upload content files
info "Uploading content files..."
scp -r content $DEPLOY_USER@$DEPLOY_HOST:/tmp/

# Step 8: Deploy on server
info "Deploying on server..."
ssh $DEPLOY_USER@$DEPLOY_HOST << 'ENDSSH'
set -e

# Stop the service
echo "Stopping service..."
sudo systemctl stop indie || true

# Backup current release
if [ -d /opt/indie/releases ]; then
    echo "Backing up current release..."
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p /opt/backups
    sudo cp -r /opt/indie /opt/backups/$BACKUP_NAME || true
fi

# Preserve .env.prod before cleaning
if [ -f /opt/indie/.env.prod ]; then
    echo "Preserving .env.prod..."
    cp /opt/indie/.env.prod /tmp/.env.prod.backup
fi

# Extract new release
echo "Extracting new release..."
sudo rm -rf /opt/indie/*
sudo tar -xzf /tmp/indie.tar.gz -C /opt/indie/

# Restore .env.prod
if [ -f /tmp/.env.prod.backup ]; then
    echo "Restoring .env.prod..."
    sudo mv /tmp/.env.prod.backup /opt/indie/.env.prod
    sudo chown indie:indie /opt/indie/.env.prod
    sudo chmod 600 /opt/indie/.env.prod
fi

# Copy content files
echo "Copying content files..."
sudo rm -rf /opt/indie/content
sudo cp -r /tmp/content /opt/indie/
sudo chown -R indie:indie /opt/indie/content

# Ensure data directory exists
sudo mkdir -p /var/lib/indie
sudo chown -R indie:indie /var/lib/indie

# Run migrations
echo "Running migrations..."
cd /opt/indie
sudo -u indie bash -c "set -a; source /opt/indie/.env.prod; set +a; /opt/indie/bin/indie eval 'Indie.Release.migrate()'" || echo "No migrations to run"

# Start the service
echo "Starting service..."
sudo systemctl start indie || {
  echo "ERROR: Failed to start service!"
  sudo journalctl -u indie -n 20 --no-pager
  exit 1
}

# Check status
sleep 2
sudo systemctl status indie --no-pager || {
  echo "WARNING: Service status check failed"
  sudo journalctl -u indie -n 30 --no-pager
}

# Cleanup
rm -f /tmp/indie.tar.gz
rm -rf /tmp/content

echo "Deployment complete!"
ENDSSH

info "Deployment completed successfully!"
info "Check logs with: ssh $DEPLOY_USER@$DEPLOY_HOST 'sudo journalctl -u indie -f'"
