#!/bin/bash
set -e

# Configuration
APP_NAME="indie"
DEPLOY_USER="indie"
DEPLOY_HOST="45.55.203.183"
DEPLOY_PATH="/opt/indie"
DATA_PATH="/var/lib/indie"

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
cd _build/prod/rel/$APP_NAME
tar -czf $APP_NAME.tar.gz .
cd -

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
    sudo mkdir -p /opt/indie/backups
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    sudo cp -r /opt/indie /opt/indie/backups/$BACKUP_NAME || true
fi

# Extract new release
echo "Extracting new release..."
sudo rm -rf /opt/indie/*
sudo tar -xzf /tmp/indie.tar.gz -C /opt/indie/

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
source /opt/indie/.env.prod
cd /opt/indie
sudo -u indie bash -c 'source /opt/indie/.env.prod && /opt/indie/bin/indie eval "Indie.Release.migrate()"' || echo "No migrations to run"

# Start the service
echo "Starting service..."
sudo systemctl start indie

# Check status
sleep 2
sudo systemctl status indie --no-pager

# Cleanup
rm -f /tmp/indie.tar.gz
rm -rf /tmp/content

echo "Deployment complete!"
ENDSSH

info "Deployment completed successfully!"
info "Check logs with: ssh $DEPLOY_USER@$DEPLOY_HOST 'sudo journalctl -u indie -f'"
