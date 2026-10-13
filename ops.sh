#!/bin/bash
# Day-to-day production helpers. Reads DEPLOY_USER / DEPLOY_HOST from .deploy.config.
set -euo pipefail

cd "$(dirname "$0")"
[ -f .deploy.config ] || { echo "Missing .deploy.config (needs DEPLOY_USER, DEPLOY_HOST)" >&2; exit 1; }
# shellcheck disable=SC1091
source .deploy.config
TARGET="$DEPLOY_USER@$DEPLOY_HOST"

case "${1:-}" in
  deploy)
    ./deploy.sh "${2:-main}"
    ;;
  logs)
    ssh "$TARGET" 'sudo journalctl -u indie -f'
    ;;
  status)
    ssh "$TARGET" 'sudo systemctl status indie; echo; echo "current -> $(readlink /opt/indie/current)"; cat /opt/indie/current/REVISION'
    ;;
  restart|stop|start)
    ssh "$TARGET" "sudo systemctl $1 indie"
    ;;
  releases)
    ssh "$TARGET" '/opt/indie/bin/rollback.sh --list'
    ;;
  rollback)
    ssh "$TARGET" "/opt/indie/bin/rollback.sh ${2:-}"
    ;;
  backup)
    ssh "$TARGET" 'set -a; . /opt/indie/shared/.env.prod; set +a; f=/var/lib/indie/backups/manual-$(date +%Y%m%d_%H%M%S).sql.gz; PGPASSWORD="$DATABASE_PASSWORD" pg_dump -h "$DATABASE_HOST" -p "$DATABASE_PORT" -U "$DATABASE_USER" "$DATABASE_NAME" | gzip > "$f" && echo "Backed up to $f"'
    ;;
  upload)
    file="${2:?usage: ops.sh upload <file> [downloads|videos]}"
    kind="${3:-downloads}"
    case "$kind" in downloads|videos) ;; *) echo "kind must be downloads or videos" >&2; exit 1 ;; esac
    scp "$file" "$TARGET:/var/lib/indie/$kind/"
    ssh "$TARGET" "chmod 644 /var/lib/indie/$kind/$(basename "$file")"
    echo "Available at https://glorifiednotepad.net/$kind/$(basename "$file")"
    ;;
  remote)
    ssh -t "$TARGET" 'set -a; . /opt/indie/shared/.env.prod; set +a; /opt/indie/current/bin/indie remote'
    ;;
  ssh)
    ssh "$TARGET"
    ;;
  nginx-logs)
    ssh "$TARGET" 'tail -f /var/log/nginx/glorifiednotepad_error.log'
    ;;
  *)
    cat <<EOF
Usage: $0 <command>

  deploy [ref]               Trigger the GitHub deploy workflow (default: main)
  logs                       Follow application logs
  status                     Service status + deployed commit
  restart|stop|start         Control the service
  releases                   List releases on the server (* = current)
  rollback [release-id]      Roll back to previous (or given) release
  backup                     pg_dump to /var/lib/indie/backups
  upload <file> [kind]       Upload to /var/lib/indie/{downloads,videos}
  remote                     IEx shell into the running app
  ssh                        SSH into the server
  nginx-logs                 Follow nginx error log
EOF
    exit 1
    ;;
esac
