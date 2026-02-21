# Deployment Files Summary

This project is now configured for deployment to Digital Ocean. All deployment-related files have been created.

## Files Created

### Application Files
- **`lib/indie/release.ex`** - Migration helper for running database migrations in production
- **`rel/overlays/bin/server`** - Custom startup script for the release

### Configuration Files
- **`.env.prod.example`** - Template for production environment variables
- **`.gitignore`** - Updated to ignore `.env.prod` and release tarballs

### Deployment Files
- **`deploy.sh`** - Automated deployment script (run from local machine)
- **`deployment/nginx.conf`** - Nginx reverse proxy configuration template
- **`deployment/indie.service`** - Systemd service configuration template
- **`DEPLOYMENT.md`** - Complete deployment guide with step-by-step instructions

### Updated Files
- **`mix.exs`** - Added release configuration

## Quick Start

1. **Read the deployment guide:**
   ```bash
   cat DEPLOYMENT.md
   ```

2. **Follow the server setup steps** in DEPLOYMENT.md (one-time setup)

3. **Deploy:**
   ```bash
   ./deploy.sh production
   ```

## Important Notes

- Never commit `.env.prod` - it contains secrets!
- The deploy script builds releases locally and uploads them to the server
- Markdown content files in `content/` are automatically copied during deployment
- SSL certificates are managed by Let's Encrypt/certbot

## Server Details

- **Host:** 45.55.203.183
- **Domain:** glorifiednotepad.net
- **Deploy User:** indie
- **App Directory:** /opt/indie
- **Data Directory:** /var/lib/indie

## Next Steps

Follow DEPLOYMENT.md for complete instructions on:
1. DNS configuration
2. Server setup (one-time)
3. First deployment
4. SSL certificate setup
5. Ongoing maintenance
