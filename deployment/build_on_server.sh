#!/bin/bash
set -e

# Configuration
REPO_DIR="/opt/indie-repo"
DEPLOY_DIR="/opt/indie"
BACKUP_DIR="/opt/indie-backups"
APP_NAME="indie"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }

# Load asdf
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    source "$HOME/.asdf/asdf.sh"
else
    error "asdf not found. Please install asdf first."
fi

log "Starting server-side deployment..."

# Step 1: Navigate to repo
cd "$REPO_DIR" || error "Failed to cd to $REPO_DIR"

# Step 2: Fetch latest from GitHub
log "Fetching latest code from GitHub..."
git fetch origin main || error "Failed to fetch from GitHub"

# Get current and new commit info
CURRENT_COMMIT=$(git rev-parse HEAD)
NEW_COMMIT=$(git rev-parse origin/main)

if [ "$CURRENT_COMMIT" = "$NEW_COMMIT" ]; then
    warn "Already at latest commit: $CURRENT_COMMIT"
    log "Proceeding with build anyway..."
else
    log "Updating from $CURRENT_COMMIT to $NEW_COMMIT"
    git reset --hard origin/main || error "Failed to reset to origin/main"
fi

# Step 3: Clean previous builds
log "Cleaning previous builds..."
rm -rf _build/prod/rel

# Step 4: Get dependencies
log "Fetching dependencies..."
mix deps.get --only prod || error "Failed to get dependencies"

# Step 4.5: Ensure build tools are available
log "Verifying build tools..."

# esbuild should already be in the repo (committed)
if [ ! -f "_build/esbuild-linux-x64" ]; then
    warn "esbuild binary not found in repo, attempting to download..."
    mix esbuild.install || error "Failed to install esbuild"
fi

# tailwind: try to download from GitHub releases (more reliable than npm)
# If download fails, use cached version if it exists
if [ ! -f "_build/tailwind-linux-x64" ]; then
    log "Downloading Tailwind CSS from GitHub releases..."
    TAILWIND_VERSION="4.1.12"
    TAILWIND_URL="https://github.com/tailwindlabs/tailwindcss/releases/download/v${TAILWIND_VERSION}/tailwindcss-linux-x64"
    
    if curl -fsSL "$TAILWIND_URL" -o "_build/tailwind-linux-x64"; then
        chmod +x _build/tailwind-linux-x64
        log "Tailwind CSS downloaded successfully"
    else
        error "Failed to download Tailwind CSS and no cached version available"
    fi
else
    log "Using cached Tailwind CSS binary"
fi

# Step 5: Compile assets
log "Compiling assets..."
cd assets
npm install || error "Failed to install npm packages"
cd ..
MIX_ENV=prod mix assets.deploy || error "Failed to compile assets"

# Step 6: Build release
log "Building release..."
MIX_ENV=prod mix release --overwrite || error "Failed to build release"

# Verify release was built
if [ ! -d "_build/prod/rel/$APP_NAME" ]; then
    error "Release directory not found after build"
fi

# Step 7: Stop service
log "Stopping service..."
sudo systemctl stop indie || warn "Service was not running"

# Step 8: Backup current release
if [ -d "$DEPLOY_DIR/releases" ]; then
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    log "Backing up current release to $BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$BACKUP_DIR"
    cp -r "$DEPLOY_DIR" "$BACKUP_DIR/$BACKUP_NAME" || warn "Backup failed (continuing anyway)"
    
    # Keep only last 5 backups
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -rf
fi

# Step 9: Preserve .env.prod
if [ -f "$DEPLOY_DIR/.env.prod" ]; then
    log "Preserving .env.prod..."
    cp "$DEPLOY_DIR/.env.prod" /tmp/.env.prod.backup
fi

# Step 10: Deploy new release
log "Deploying new release..."
cd "$REPO_DIR"
rm -rf "$DEPLOY_DIR"/*
cp -r _build/prod/rel/$APP_NAME/* "$DEPLOY_DIR/" || error "Failed to copy release"

# Restore .env.prod
if [ -f /tmp/.env.prod.backup ]; then
    cp /tmp/.env.prod.backup "$DEPLOY_DIR/.env.prod"
    chmod 600 "$DEPLOY_DIR/.env.prod"
    rm /tmp/.env.prod.backup
fi

# Copy content files
log "Copying content files..."
rm -rf "$DEPLOY_DIR/content"
cp -r content "$DEPLOY_DIR/"

# Ensure data directory exists
mkdir -p /var/lib/indie

# Step 11: Run migrations
log "Running migrations..."
cd "$DEPLOY_DIR"
set +e
# Run migration with environment variables from .env.prod
env $(cat "$DEPLOY_DIR/.env.prod" | xargs) "$DEPLOY_DIR/bin/indie" eval 'Indie.Release.migrate()' 2>&1
MIGRATION_EXIT=$?
set -e

if [ $MIGRATION_EXIT -ne 0 ]; then
    warn "Migrations failed with exit code $MIGRATION_EXIT (continuing anyway)"
fi

# Step 12: Start service
log "Starting service..."
sudo systemctl start indie || error "Failed to start service"

# Wait for service to start
sleep 3

# Step 13: Check service status
log "Checking service status..."
if sudo systemctl is-active --quiet indie; then
    echo ""
    log "${GREEN}✓ Deployment successful!${NC}"
    log "Deployed commit: $NEW_COMMIT"
    log "View logs: sudo journalctl -u indie -f"
    echo ""
else
    error "Service failed to start! Check logs: sudo journalctl -u indie -n 50"
fi

log "Done!"
