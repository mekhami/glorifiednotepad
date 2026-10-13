# Cutover checklist: server-built deploys → GitHub Actions

Run these by hand, in order. Each phase ends with a check. Stop if a check fails.
`$HOST` = the server IP/host from `.deploy.config`.

The old layout (`/opt/indie` = the release itself) keeps serving until Phase 4.

Files under `deployment/` exist only on your Mac, not the server. Where a step needs one,
copy it first, e.g. `scp deployment/indie.service indie@$HOST:~`.

`.env.prod` must use plain `KEY=value` lines. systemd ignores lines that start with `export`.

---

## Phase 1 — CI only (no server changes)

1. Push this branch and open a PR. Do **not** merge yet.
2. In GitHub → Actions, confirm the **Test** and **Build release** jobs are green.
   - Deploy is skipped on PRs. That's expected. The release tarball is attached to the run
     as an artifact if you want to inspect it.

✅ Check: Test + Build green on the PR.

---

## Phase 2 — GitHub setup (no server changes)

1. **Create a deploy key** (locally, no passphrase):
   ```bash
   ssh-keygen -t ed25519 -N "" -C "github-actions-deploy" -f ~/.ssh/indie_deploy
   ```
2. **Authorize it on the server:**
   ```bash
   ssh-copy-id -i ~/.ssh/indie_deploy.pub indie@$HOST
   ssh -i ~/.ssh/indie_deploy indie@$HOST 'echo ok'
   ```
3. **Capture the host key:**
   ```bash
   ssh-keyscan -t ed25519,rsa $HOST
   ```
   Compare the fingerprint to `ssh-keygen -lf <(ssh-keyscan $HOST)` versus what's in your
   `~/.ssh/known_hosts` for that host. They must match.
4. **GitHub → Settings → Environments → New environment `production`.** Under
   "Deployment branches", restrict it to `main`. Then only code on `main` can use the
   deploy key. Add secrets:
   | Secret | Value |
   |---|---|
   | `SSH_PRIVATE_KEY` | contents of `~/.ssh/indie_deploy` |
   | `SSH_KNOWN_HOSTS` | output of the `ssh-keyscan` above |
   | `SSH_HOST` | server IP |
   | `SSH_USER` | `indie` |

✅ Check: environment `production` exists with 4 secrets.

---

## Phase 3 — Prepare the server (old app keeps running)

SSH in as `indie` (or any sudo-capable user) and prefix commands with `sudo` as needed.

1. **Tools needed by the activate script:**
   ```bash
   which pg_dump curl gzip tar    # all should resolve
   ```
2. **Record what's currently deployed** (for reference):
   ```bash
   ls /opt/indie /opt/indie/lib/indie-*/priv/static/downloads /opt/indie/lib/indie-*/priv/static/videos
   ls /opt/indie/bin/priv/static/uploads /opt/indie/priv/static/uploads 2>/dev/null   # old stonetop avatar uploads, if any
   ls /var/lib/indie /var/lib/indie/videos 2>/dev/null
   ```
3. **Snapshot the old app dir** (the fallback for this whole process):
   ```bash
   cp -a /opt/indie /opt/indie-legacy
   ```
4. **Back up the database:**
   ```bash
   set -a; . /opt/indie/.env.prod; set +a
   PGPASSWORD="$DATABASE_PASSWORD" pg_dump -h localhost -U "$DATABASE_USER" "$DATABASE_NAME" \
     | gzip > /var/lib/indie/backups/pre-cutover.sql.gz
   ls -lh /var/lib/indie/backups/pre-cutover.sql.gz   # should be non-trivial size
   ```
5. **Create the persistent directories** and move uploaded files into them:
   ```bash
   mkdir -p /var/lib/indie/{downloads,videos,uploads,backups}
   cp -a /opt/indie/lib/indie-*/priv/static/downloads/. /var/lib/indie/downloads/ 2>/dev/null || true
   # Any old stonetop uploads found in step 2:
   #   cp -a <that-dir>/. /var/lib/indie/uploads/
   # /var/lib/indie/videos already holds the extra videos, if any.
   chown -R indie:indie /var/lib/indie
   chmod 755 /var/lib/indie /var/lib/indie/{downloads,videos,uploads}
   find /var/lib/indie/{downloads,videos,uploads} -type f -exec chmod 644 {} +
   chmod 700 /var/lib/indie/backups
   ```
   nginx (`www-data`) needs to read the downloads/videos/uploads dirs. It must **not**
   be able to read backups.
6. **Create the shared env file:**
   ```bash
   mkdir -p /opt/indie/shared
   cp /opt/indie/.env.prod /opt/indie/shared/.env.prod
   echo 'UPLOADS_DIR=/var/lib/indie/uploads' >> /opt/indie/shared/.env.prod
   echo 'CONTENT_DIR=/opt/indie/current/content' >> /opt/indie/shared/.env.prod
   chmod 600 /opt/indie/shared/.env.prod
   chown -R indie:indie /opt/indie/shared
   ```
7. **Optional: install the narrowed sudoers rule.** Skip this unless you have root access
   some other way, such as root SSH or the Digital Ocean droplet console. Removing a broad
   `NOPASSWD: ALL` rule from `indie` can lock you out of sudo. First check for an existing
   rule (`sudo -l -U indie`, `ls /etc/sudoers.d`). Then copy `deployment/indie.sudoers` to the server and:
   ```bash
   install -m 440 indie.sudoers /etc/sudoers.d/indie
   visudo -c
   sudo -u indie sudo -n /usr/bin/systemctl is-active indie   # should print "active", no password prompt
   ```
   If an older, broader rule for `indie` exists, remove it once the new one works.

✅ Check: site still up (old layout untouched). `/opt/indie-legacy` and `pre-cutover.sql.gz` exist.

---

## Phase 4 — Switch layout and run the first CI deploy (brief downtime)

1. **Rebuild `/opt/indie` in the new layout.** Downtime starts here.
   ```bash
   systemctl stop indie
   mv /opt/indie /opt/indie-old-layout
   mkdir -p /opt/indie/{releases,incoming,bin}
   mv /opt/indie-old-layout/shared /opt/indie/shared
   cp -a /opt/indie-legacy /opt/indie/releases/legacy
   rm -f /opt/indie/releases/legacy/.env.prod          # secrets live in shared/ now
   echo legacy > /opt/indie/releases/legacy/REVISION
   ln -sfn /opt/indie/releases/legacy /opt/indie/current
   chown -R indie:indie /opt/indie
   ```
   Delete `/opt/indie-old-layout` once Phase 4 passes. `/opt/indie-legacy` is the real backup.
2. **Install the new systemd unit** (`deployment/indie.service`):
   ```bash
   # from your Mac: scp deployment/indie.service indie@$HOST:~
   sudo cp ~/indie.service /etc/systemd/system/indie.service
   systemctl daemon-reload
   systemctl start indie
   curl -sI -H 'X-Forwarded-Proto: https' -H 'Host: glorifiednotepad.net' http://127.0.0.1:4000/ | head -1
   ```
   The old release should now be running from `current`. Open the site and check that
   posts render. Posts come from `releases/legacy/content`.

   If it crash-loops, check `sudo journalctl -u indie -n 80 --no-pager`. The `CONTENT_DIR`
   line from Phase 3 step 6 is what lets the legacy release find its posts.
3. **Update nginx.** Certbot has edited the live config, so **do not overwrite it**. Copy just
   the four new `location` blocks (`/downloads/`, `/videos/`, `/uploads/`, `@phoenix`) from
   `deployment/nginx.conf` into the `listen 443` server block of
   `/etc/nginx/sites-available/glorifiednotepad.net`. Then:
   ```bash
   nginx -t && systemctl reload nginx
   ```
4. **Merge the PR to `main`.** The workflow runs Test → Build → Deploy automatically.
   Watch the Deploy job log. You should see unpack, DB backup, migrations, switch, and
   "Healthy".
5. **Verify:**
   ```bash
   ./ops.sh status        # current -> releases/<ts>-<sha>, REVISION = merged sha
   ./ops.sh releases
   ```
   In a browser, check: home page, a post, a video page, a downloads link, the stonetop page,
   and LiveView pages (comments, doodle).

✅ Check: site serves the new commit. `ops.sh releases` shows `legacy` + the new release.

**If the deploy fails:** the script rolls back automatically. If something is still wrong:
`./ops.sh rollback legacy`. Total fallback: restore `/opt/indie-legacy` and the old
`indie.service` from git history (`git show HEAD~1:deployment/indie.service`).

---

## Phase 5 — Prove rollback works

1. `./ops.sh rollback legacy`, then check the site.
2. `./ops.sh rollback <new-release-id>` (from `./ops.sh releases`), then check the site.
3. Optional: push a commit to a throwaway branch that makes `/` return 500. Use
   `./deploy.sh <that-sha>` and confirm the job fails and the site stays up on the
   previous release. Then delete the branch.

---

## Phase 6 — Cleanup (after about a week of good deploys)

```bash
rm -rf /opt/indie-legacy /opt/indie-backups
rm -rf /opt/indie/releases/legacy     # once it's no longer the rollback target
```
Leave `/opt/indie-repo` and asdf in place until `seed_logo` is reworked to run against the
release instead of Mix.

Consider upgrading the server to Ubuntu 24.04 LTS or 26.04 LTS. 24.10 is end-of-life.
Since CI builds the release, a fresh server only needs Postgres, nginx, certbot and these
steps.
