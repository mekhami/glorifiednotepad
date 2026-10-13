# Deployment: glorifiednotepad.net

Production runs on a single Digital Ocean droplet: a Mix release under systemd, behind
nginx, with PostgreSQL 16 on localhost. The release is built in GitHub Actions. The server
never compiles anything.

## How a deploy works

Every push runs **Test** (`.github/workflows/ci.yml`). A push to `main` also runs:

1. **Build.** On an `ubuntu-24.04` runner: `mix assets.deploy` and `mix release`. The
   tarball includes `content/`.
2. **Deploy.** Uses the `production` GitHub environment, one deploy at a time. It scp's the
   tarball and `deployment/*.sh` to the server, then runs
   `deployment/activate_release.sh`, which:
   - unpacks to `/opt/indie/releases/<timestamp>-<sha>`
   - `pg_dump`s to `/var/lib/indie/backups/pre-deploy-*.sql.gz` (keeps 10)
   - runs migrations with the new release. **On failure it aborts, and nothing changes.**
   - repoints `/opt/indie/current` and restarts `indie`, which means a few seconds of downtime
   - checks that `/` responds within 30s. **On failure it repoints to the previous release
     and fails the job.**
   - prunes old releases (keeps 5)

Migrations are never rolled back automatically. A deploy that fails its health check after
migrating leaves the new schema in place, and the pre-deploy dump is your undo.

## Server layout

```
/opt/indie/
  current -> releases/<id>     systemd runs current/bin/server
  releases/<ts>-<sha>/         one per deploy; REVISION holds the full sha
  shared/.env.prod             secrets (see .env.prod.example + UPLOADS_DIR)
  incoming/                    tarballs in transit
  bin/                         activate_release.sh, rollback.sh (copied each deploy)
/var/lib/indie/
  downloads/  videos/          served by nginx at /downloads/, /videos/ (fall back to Phoenix)
  uploads/                     stonetop avatar uploads, served by nginx at /uploads/
  backups/                     DB dumps
```

Config files in this repo: `deployment/indie.service` (systemd),
`deployment/nginx.conf` (merge the `location` blocks into the certbot-managed config, don't
overwrite it), and `deployment/indie.sudoers`.

## Everyday commands

```bash
./deploy.sh [ref]          # manually (re)deploy main or any sha/tag via GitHub (needs `gh`)
./ops.sh status            # service status + deployed sha
./ops.sh logs
./ops.sh releases          # list releases, * = current
./ops.sh rollback [id]     # previous release, or a specific one
./ops.sh backup            # manual pg_dump
./ops.sh upload file.dmg   # → /var/lib/indie/downloads (or: upload clip.mp4 videos)
./ops.sh remote            # IEx into the running app
```

`ops.sh` reads `DEPLOY_USER` and `DEPLOY_HOST` from `.deploy.config` (gitignored).

## Restoring the database

```bash
ssh indie@$HOST
set -a; . /opt/indie/shared/.env.prod; set +a
sudo systemctl stop indie
gunzip -c /var/lib/indie/backups/pre-deploy-<id>.sql.gz \
  | PGPASSWORD="$DATABASE_PASSWORD" psql -h localhost -U "$DATABASE_USER" -d "$DATABASE_NAME"
```
To restore cleanly, drop and recreate the DB first (as the `postgres` user).
Then `./ops.sh rollback <matching-release>`.

## GitHub configuration

Environment **`production`** with secrets `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`, `SSH_HOST`
and `SSH_USER`. See `deployment/CUTOVER.md` for how to create them.

## Fresh server setup

1. Ubuntu LTS: `apt install nginx certbot python3-certbot-nginx postgresql-16 curl`.
   No Erlang or Elixir needed.
2. Create the `indie` system user and the Postgres DB and user (`indie_prod` / `indie`).
3. Create `/opt/indie/{releases,shared,incoming,bin}` and
   `/var/lib/indie/{downloads,videos,uploads,backups}`, owned by `indie`. Media dirs are
   755, backups are 700.
4. Write `/opt/indie/shared/.env.prod` from `.env.prod.example` (chmod 600).
5. Install `indie.service` (`systemctl enable indie`), the sudoers file and the nginx site.
   Then run `certbot --nginx -d glorifiednotepad.net -d www.glorifiednotepad.net`.
6. Add the deploy public key to `~indie/.ssh/authorized_keys` and update the GitHub secrets.
7. `./deploy.sh main`.

## Troubleshooting

- **Deploy job failed.** The job log shows which step failed. For a failed health check it
  includes the last 50 journal lines.
- **App won't start.** Run `./ops.sh logs`. Usually the cause is a missing variable in
  `shared/.env.prod` or Postgres being down (`systemctl status postgresql`).
- **Migration by hand:**
  `set -a; . /opt/indie/shared/.env.prod; set +a; /opt/indie/current/bin/indie eval 'Indie.Release.migrate()'`
- **Library errors at startup** (e.g. `libcrypto`, `GLIBC_x.y`). The CI runner and the
  server have drifted apart. The server's Ubuntu version must be the same as or newer than
  the CI runner's (`ubuntu-24.04`).
