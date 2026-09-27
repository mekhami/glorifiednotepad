# Deployment Files Summary

This project is now configured for deployment to Digital Ocean. All deployment-related files have been created.

## Files Created

### Application Files
- **`lib/indie/release.ex`** - Migration helper for running database migrations in production
- **`rel/overlays/bin/server`** - Custom startup script for the release

### Configuration Files
- **`.env.prod.example`** - Template for production environment variables (PostgreSQL)
- **`.gitignore`** - Updated to ignore `.env.prod` and release tarballs

### Deployment Files
- **`deploy.sh`** - Automated deployment script (run from local machine)
- **`deployment/nginx.conf`** - Nginx reverse proxy configuration template
- **`deployment/indie.service`** - Systemd service configuration template
- **`DEPLOYMENT.md`** - Complete deployment guide with step-by-step instructions
- **`priv/scripts/migrate_sqlite_to_pg.sh`** - SQLite to PostgreSQL migration script

### Updated Files
- **`mix.exs`** - Added release configuration
- **`config/runtime.exs`** - Updated production database config for PostgreSQL

## Quick Start

1. **Read the deployment guide:**
   ```bash
   cat DEPLOYMENT.md
   ```

2. **Follow the server setup steps** in DEPLOYMENT.md (one-time setup)
   - Now includes PostgreSQL 16 installation and configuration

3. **Deploy:**
   ```bash
   ./deploy.sh production
   ```

## Important Notes

- Never commit `.env.prod` - it contains secrets!
- The deploy script builds releases locally and uploads them to the server
- Markdown content files in `content/` are automatically copied during deployment
- SSL certificates are managed by Let's Encrypt/certbot
- **Database:** Now uses PostgreSQL (was SQLite)

## Server Details

- **Host:** 45.55.203.183
- **Domain:** glorifiednotepad.net
- **Deploy User:** indie
- **App Directory:** /opt/indie
- **Data Directory:** /var/lib/indie (for backups, uploads, static assets)
- **Database:** PostgreSQL 16 on localhost:5432, database `indie_prod`

## Next Steps

Follow DEPLOYMENT.md for complete instructions on:
1. DNS configuration
2. Server setup (one-time) - now includes PostgreSQL
3. First deployment
4. SSL certificate setup
5. SQLite to PostgreSQL migration (if you have existing data)
6. Ongoing maintenance