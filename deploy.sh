#!/bin/bash
# Deploys happen automatically on push to main via GitHub Actions
# (.github/workflows/ci.yml). Use this to manually (re)deploy a ref:
#
#   ./deploy.sh            # redeploy main
#   ./deploy.sh <sha|tag>  # deploy a specific commit (e.g. to roll forward/back)
#
# Requires the GitHub CLI (`brew install gh`, then `gh auth login`).
set -euo pipefail

REF="${1:-main}"
command -v gh >/dev/null || { echo "Install the GitHub CLI: brew install gh" >&2; exit 1; }

gh workflow run ci.yml -f ref="$REF"
echo "Triggered deploy of '$REF'. Watch with: gh run watch"
