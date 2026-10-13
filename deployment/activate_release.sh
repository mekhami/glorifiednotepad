#!/bin/bash
# Activates a release tarball built by CI.
#
#   activate_release.sh <tarball> <git-sha>
#
# Runs as the deploy user on the server. Steps:
#   1. unpack into /opt/indie/releases/<timestamp>-<sha>
#   2. pg_dump the database
#   3. run migrations with the NEW release (abort on failure, nothing switched)
#   4. point /opt/indie/current at the new release and restart
#   5. health check; on failure, point back at the previous release and restart
#   6. prune old releases and backups
set -euo pipefail

TARBALL="${1:?usage: activate_release.sh <tarball> <git-sha>}"
SHA="${2:?usage: activate_release.sh <tarball> <git-sha>}"

APP_ROOT="/opt/indie"
RELEASES_DIR="$APP_ROOT/releases"
CURRENT_LINK="$APP_ROOT/current"
ENV_FILE="$APP_ROOT/shared/.env.prod"
BACKUP_DIR="/var/lib/indie/backups"
KEEP_RELEASES=5
KEEP_BACKUPS=10
HEALTH_TIMEOUT=30

log() { echo "[$(date +'%H:%M:%S')] $*"; }
die() { echo "[$(date +'%H:%M:%S')] ERROR: $*" >&2; exit 1; }

[ -f "$TARBALL" ] || die "tarball not found: $TARBALL"
[ -f "$ENV_FILE" ] || die "env file not found: $ENV_FILE"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

RELEASE_ID="$(date +%Y%m%d%H%M%S)-${SHA:0:7}"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"
PREVIOUS="$(readlink "$CURRENT_LINK" 2>/dev/null || true)"

log "Unpacking $TARBALL -> $RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
tar -xzf "$TARBALL" -C "$RELEASE_DIR"
echo "$SHA" > "$RELEASE_DIR/REVISION"

log "Backing up database"
mkdir -p "$BACKUP_DIR"
DUMP="$BACKUP_DIR/pre-deploy-$RELEASE_ID.sql.gz"
PGPASSWORD="$DATABASE_PASSWORD" pg_dump \
  -h "${DATABASE_HOST:-localhost}" -p "${DATABASE_PORT:-5432}" \
  -U "$DATABASE_USER" "$DATABASE_NAME" | gzip > "$DUMP" \
  || { rm -f "$DUMP"; rm -rf "$RELEASE_DIR"; die "pg_dump failed; aborting before any changes"; }
log "Database backed up to $DUMP"

log "Running migrations"
if ! "$RELEASE_DIR/bin/indie" eval 'Indie.Release.migrate()'; then
  rm -rf "$RELEASE_DIR"
  die "migrations failed; current release left running (${PREVIOUS:-none})"
fi

switch_to() {
  ln -sfn "$1" "$CURRENT_LINK.tmp"
  mv -Tf "$CURRENT_LINK.tmp" "$CURRENT_LINK"
  sudo /usr/bin/systemctl restart indie
}

healthy() {
  local i
  for ((i = 0; i < HEALTH_TIMEOUT; i++)); do
    if curl -fsS -o /dev/null --max-time 5 \
      -H "Host: ${PHX_HOST:-glorifiednotepad.net}" \
      -H "X-Forwarded-Proto: https" \
      "http://127.0.0.1:${PORT:-4000}/"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

log "Switching current -> $RELEASE_DIR and restarting"
switch_to "$RELEASE_DIR"

log "Health check (up to ${HEALTH_TIMEOUT}s)"
if ! healthy; then
  sudo /usr/bin/journalctl -u indie -n 50 --no-pager || true
  if [ -n "$PREVIOUS" ] && [ -d "$PREVIOUS" ]; then
    log "Health check failed; rolling back to $PREVIOUS"
    switch_to "$PREVIOUS"
    rm -rf "$RELEASE_DIR"
    healthy && log "Previous release is healthy again" || log "Previous release ALSO unhealthy — investigate now"
    log "Note: migrations from the failed release were NOT reverted. Backup: $DUMP"
  fi
  die "deploy of $SHA failed health check"
fi

log "Healthy. Pruning old releases and backups"
# shellcheck disable=SC2012
ls -1dt "$RELEASES_DIR"/*/ | tail -n +$((KEEP_RELEASES + 1)) | while read -r old; do
  [ "${old%/}" = "$PREVIOUS" ] && continue
  rm -rf "$old"
done
# shellcheck disable=SC2012
ls -1t "$BACKUP_DIR"/pre-deploy-*.sql.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
rm -f "$TARBALL"

log "Deployed $SHA as $RELEASE_ID"
