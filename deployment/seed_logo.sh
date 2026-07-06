#!/bin/bash
# Runs the seed_logo.exs script on the server.
# Can be called manually or via cron.
set -e

REPO_DIR="/opt/indie-repo"
DEPLOY_DIR="/opt/indie"

cd "$REPO_DIR"

# Load asdf (Elixir/Erlang version manager)
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
else
  echo "asdf not found at $HOME/.asdf/asdf.sh" >&2
  exit 1
fi

# Load production env vars (DATABASE_PATH, SECRET_KEY_BASE, etc.)
export $(cat "$DEPLOY_DIR/.env.prod" | xargs)
export MIX_ENV=prod

mix run priv/scripts/seed_logo.exs
