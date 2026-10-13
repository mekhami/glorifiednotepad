# deployment/

| File | Purpose |
|---|---|
| `activate_release.sh` | Runs on the server for each deploy: unpack, backup, migrate, switch, health check, auto-rollback |
| `rollback.sh` | Repoints `/opt/indie/current` at an earlier release (`./ops.sh rollback`) |
| `indie.service` | systemd unit → `/etc/systemd/system/indie.service` |
| `nginx.conf` | Reference nginx site. Merge into the certbot-managed config, don't overwrite it |
| `indie.sudoers` | Lets the `indie` user restart the service → `/etc/sudoers.d/indie` |
| `CUTOVER.md` | One-time migration from server-side builds to GitHub Actions |

See `../DEPLOYMENT.md` for the full picture.
