#!/bin/bash
set -e

# Configuration
APP_NAME="indie"
BLUE='\033[0;34m'
FORCE_DEPLOY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_DEPLOY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force|-f]"
            exit 1
            ;;
    esac
done

# Load deploy configuration from .deploy.config
if [ -f ".deploy.config" ]; then
    source .deploy.config
else
    echo "Error: .deploy.config file not found"
    echo "Please create .deploy.config with the following variables:"
    echo "  DEPLOY_USER"
    echo "  DEPLOY_HOST"
    echo "  DEPLOY_PATH"
    echo "  REPO_PATH"
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

info "🔍 Running pre-flight checks..."

# Check 1: Verify on main branch (warn but don't block)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    warn "You are on branch '$CURRENT_BRANCH', not 'main'"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Deployment cancelled"
    fi
fi

# Check 2: Verify no uncommitted changes
if ! git diff-index --quiet HEAD --; then
    error "You have uncommitted changes. Commit or stash them first."
fi

# Check 3: Verify up-to-date with remote
info "Fetching latest from GitHub..."
git fetch origin main --quiet

LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/main)

if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    error "Your local branch is not in sync with origin/main. Pull or push first."
fi

# Get commit info for display
COMMIT_SHA=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B)
COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an')
COMMIT_DATE=$(git log -1 --pretty=format:'%ar')

# Check 4: Check if there are new commits to deploy
info "Checking for new commits on server..."
SERVER_COMMIT=$(ssh $DEPLOY_USER@$DEPLOY_HOST "cd $REPO_PATH && git rev-parse HEAD 2>/dev/null || echo 'none'")

if [ "$SERVER_COMMIT" = "$LOCAL_COMMIT" ]; then
    if [ "$FORCE_DEPLOY" = false ]; then
        warn "Server is already at commit $COMMIT_SHA"
        warn "No new commits to deploy."
        echo ""
        error "Use --force flag to deploy anyway: ./deploy.sh --force"
    else
        warn "Server is already at commit $COMMIT_SHA (deploying anyway due to --force flag)"
    fi
elif [ "$SERVER_COMMIT" = "none" ]; then
    info "Server repository not found or first deployment"
else
    SERVER_COMMIT_SHORT=$(echo "$SERVER_COMMIT" | cut -c1-7)
    info "Server is at commit $SERVER_COMMIT_SHORT, will update to $COMMIT_SHA"
fi

# Check 5: Show deployment info

echo ""
info "📦 Deployment Summary:"
echo -e "${BLUE}  Commit:${NC}  $COMMIT_SHA"
echo -e "${BLUE}  Author:${NC}  $COMMIT_AUTHOR"
echo -e "${BLUE}  Date:${NC}    $COMMIT_DATE"
echo -e "${BLUE}  Message:${NC} $COMMIT_MSG"
echo ""

# Confirmation prompt
read -p "Deploy this commit to production? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Deployment cancelled by user"
    exit 0
fi

info "🚀 Starting deployment to production..."
echo ""

# SSH to server and run build script
ssh -t $DEPLOY_USER@$DEPLOY_HOST "bash $REPO_PATH/deployment/build_on_server.sh"

echo ""
info "✅ Deployment complete!"
info "Check logs: ssh $DEPLOY_USER@$DEPLOY_HOST 'sudo journalctl -u indie -f'"
