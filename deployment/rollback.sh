#!/bin/bash
# Points /opt/indie/current at a previous release and restarts.
#
#   rollback.sh            # roll back to the release before current
#   rollback.sh <id>       # roll back to /opt/indie/releases/<id>
#   rollback.sh --list     # show available releases
#
# Does NOT revert database migrations. Restore from
# /var/lib/indie/backups/pre-deploy-*.sql.gz if needed.
set -euo pipefail

RELEASES_DIR="/opt/indie/releases"
CURRENT_LINK="/opt/indie/current"
CURRENT="$(readlink "$CURRENT_LINK" 2>/dev/null || true)"

list() {
  for dir in $(ls -1dt "$RELEASES_DIR"/*/); do
    dir="${dir%/}"
    marker=" "
    [ "$dir" = "$CURRENT" ] && marker="*"
    echo "$marker $(basename "$dir")  $(cat "$dir/REVISION" 2>/dev/null || echo '?')"
  done
}

if [ "${1:-}" = "--list" ]; then
  list
  exit 0
fi

if [ -n "${1:-}" ]; then
  TARGET="$RELEASES_DIR/$1"
else
  TARGET="$(ls -1dt "$RELEASES_DIR"/*/ | sed 's:/$::' | grep -vxF "$CURRENT" | head -n 1 || true)"
fi

[ -n "$TARGET" ] && [ -d "$TARGET" ] || { echo "No such release: ${TARGET:-<none>}" >&2; list; exit 1; }

echo "Rolling back: $(basename "$CURRENT") -> $(basename "$TARGET")"
ln -sfn "$TARGET" "$CURRENT_LINK.tmp"
mv -Tf "$CURRENT_LINK.tmp" "$CURRENT_LINK"
sudo /usr/bin/systemctl restart indie
sleep 3
sudo /usr/bin/systemctl is-active indie
