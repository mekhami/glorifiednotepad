# Deployment Guide: glorifiednotepad.net

This guide covers deploying your Phoenix application to Digital Ocean at **45.55.203.183** using mix release, systemd, and nginx.

## Table of Contents

1. [DNS Configuration](#dns-configuration)
2. [Server Setup](#server-setup)
3. [First Deployment](#first-deployment)
4. [Subsequent Deployments](#subsequent-deployments)
5. [Troubleshooting](#troubleshooting)
6. [Maintenance](#maintenance)

---

## DNS Configuration

### Step 1: Add A Record

1. Log into your domain registrar (where you purchased glorifiednotepad.net)
2. Navigate to DNS settings
3. Add an A record:
   - **Name/Host:** `@` (root domain)
   - **Type:** A
   - **Value:** `45.55.203.183`
   - **TTL:** 3600 (or default)

4. Optional - Add www subdomain:
   - **Name/Host:** `www`
   - **Type:** CNAME
   - **Value:** `glorifiednotepad.net`

### Step 2: Verify DNS

Wait 5-15 minutes, then verify:

```bash
# From your local machine
dig glorifiednotepad.net
# or
nslookup glorifiednotepad.net
```

Should return `45.55.203.183`

---

## Server Setup

These steps are performed **once** on your Digital Ocean droplet.

### 1. Install Dependencies

SSH into your server:

```bash
ssh root@45.55.203.183
```

Install required packages:

```bash
# Update system
apt update && apt upgrade -y

# Install Erlang and Elixir (Ubuntu 24.10 should have recent versions)
apt install -y erlang elixir

# Verify versions
elixir --version  # Should be 1.15+
erl -version      # Should be OTP 25+

# Install nginx and certbot
apt install -y nginx certbot python3-certbot-nginx

# Install git (if not already installed)
apt install -y git
```

### 2. Create Application User

```bash
# Create a system user for running the app
adduser --system --group --home /home/indie indie
```

### 3. Create Directories

```bash
# Application directory
mkdir -p /opt/indie
chown indie:indie /opt/indie

# Data directory (for SQLite database)
mkdir -p /var/lib/indie
chown indie:indie /var/lib/indie

# Backup directory
mkdir -p /var/lib/indie/backups
chown indie:indie /var/lib/indie/backups
```

### 4. Set Up SSH Key for Deployment User

On your **local machine**, copy your SSH public key to the deployment user:

```bash
# Copy your public key to the server
ssh-copy-id indie@45.55.203.183
```

If that doesn't work, manually add your public key:

```bash
# On the server as root
mkdir -p /home/indie/.ssh
chmod 700 /home/indie/.ssh
cat >> /home/indie/.ssh/authorized_keys
# Paste your public key from ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub
# Press Ctrl+D
chmod 600 /home/indie/.ssh/authorized_keys
chown -R indie:indie /home/indie/.ssh
```

Test it:

```bash
# From your local machine
ssh indie@45.55.203.183
```

### 5. Configure Nginx

Copy the nginx configuration:

```bash
# On the server
cat > /etc/nginx/sites-available/glorifiednotepad.net << 'EOF'
upstream phoenix {
    server 127.0.0.1:4000;
}

server {
    listen 80;
    listen [::]:80;
    server_name glorifiednotepad.net www.glorifiednotepad.net;

    access_log /var/log/nginx/glorifiednotepad_access.log;
    error_log /var/log/nginx/glorifiednotepad_error.log;

    location / {
        proxy_pass http://phoenix;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;

        # Timeouts for LiveView connections
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # Serve static files directly
    location ~* ^.+\.(css|js|jpg|jpeg|gif|png|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://phoenix;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_cache_valid 200 60m;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
ln -s /etc/nginx/sites-available/glorifiednotepad.net /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Reload nginx
systemctl reload nginx
```

### 6. Configure Systemd Service

Create the systemd service file:

```bash
# On the server
cat > /etc/systemd/system/indie.service << 'EOF'
[Unit]
Description=glorified notepad Phoenix application
After=network.target

[Service]
Type=simple
User=indie
Group=indie
WorkingDirectory=/opt/indie
EnvironmentFile=/opt/indie/.env.prod
ExecStart=/opt/indie/bin/server
Restart=on-failure
RestartSec=5
RemainAfterExit=no
StandardOutput=journal
StandardError=journal
SyslogIdentifier=indie

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/indie /opt/indie

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable service to start on boot
systemctl enable indie
```

### 7. Create Environment Variables File

**IMPORTANT:** Generate a new secret key base from your **local machine**:

```bash
# On your local machine
cd /path/to/indie
mix phx.gen.secret
```

Copy the output, then create the `.env.prod` file on the **server**:

```bash
# On the server as indie user
sudo -u indie nano /opt/indie/.env.prod
```

Add this content (replace `YOUR_SECRET_KEY_BASE` with the generated value):

```bash
export SECRET_KEY_BASE=YOUR_SECRET_KEY_BASE
export PHX_SERVER=true
export PORT=4000
export DATABASE_PATH=/var/lib/indie/indie_prod.db
export PHX_HOST=glorifiednotepad.net
export POOL_SIZE=5
```

Save and exit (Ctrl+X, Y, Enter).

Set proper permissions:

```bash
chmod 600 /opt/indie/.env.prod
chown indie:indie /opt/indie/.env.prod
```

### 8. Configure Firewall (Optional but Recommended)

```bash
# Allow SSH, HTTP, and HTTPS
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```

---

## First Deployment

From your **local machine**:

### 1. Ensure Code is Committed

```bash
cd /Users/v507614/Projects/indie/indie
git add .
git commit -m "Add deployment configuration"
git push origin main
```

### 2. Run Deployment Script

```bash
./deploy.sh production
```

This will:
- Build the release locally
- Upload to the server
- Extract and deploy
- Run migrations
- Start the service

### 3. Check Deployment

```bash
# Check service status
ssh indie@45.55.203.183 'sudo systemctl status indie'

# View logs
ssh indie@45.55.203.183 'sudo journalctl -u indie -f'
```

### 4. Test the Site

Visit http://glorifiednotepad.net - you should see your site!

### 5. Set Up SSL Certificate

Once the site is accessible via HTTP, add HTTPS:

```bash
# On the server
sudo certbot --nginx -d glorifiednotepad.net -d www.glorifiednotepad.net
```

Follow the prompts:
- Enter your email
- Agree to terms
- Choose whether to redirect HTTP to HTTPS (recommended: yes)

Certbot will automatically:
- Verify domain ownership
- Issue the certificate
- Modify nginx config for HTTPS
- Set up auto-renewal

Test auto-renewal:

```bash
sudo certbot renew --dry-run
```

### 6. Verify HTTPS

Visit https://glorifiednotepad.net - should show a valid SSL certificate!

---

## Subsequent Deployments

After the initial setup, deploying updates is simple:

```bash
# From your local machine
cd /Users/v507614/Projects/indie/indie

# Make your changes, then commit
git add .
git commit -m "Your changes"
git push

# Deploy
./deploy.sh production
```

The script will:
- Build a fresh release
- Upload to server
- Stop the service
- Replace old version
- Run migrations
- Restart the service

---

## Troubleshooting

### Check Service Status

```bash
ssh indie@45.55.203.183 'sudo systemctl status indie'
```

### View Logs

```bash
# Follow live logs
ssh indie@45.55.203.183 'sudo journalctl -u indie -f'

# View last 100 lines
ssh indie@45.55.203.183 'sudo journalctl -u indie -n 100'

# Check nginx logs
ssh indie@45.55.203.183 'sudo tail -f /var/log/nginx/glorifiednotepad_error.log'
```

### Service Won't Start

Check logs for errors:

```bash
ssh indie@45.55.203.183 'sudo journalctl -u indie -xe'
```

Common issues:
- Missing environment variables in `.env.prod`
- Wrong file permissions
- Port 4000 already in use
- Database file permissions

### Database Issues

```bash
# Check database file exists and has correct permissions
ssh indie@45.55.203.183 'ls -la /var/lib/indie/'

# Fix permissions if needed
ssh indie@45.55.203.183 'sudo chown indie:indie /var/lib/indie/indie_prod.db*'
```

### Run Migration Manually

```bash
ssh indie@45.55.203.183
sudo -u indie bash -c 'source /opt/indie/.env.prod && /opt/indie/bin/indie eval "Indie.Release.migrate()"'
```

### Nginx Issues

```bash
# Test nginx config
ssh indie@45.55.203.183 'sudo nginx -t'

# Reload nginx
ssh indie@45.55.203.183 'sudo systemctl reload nginx'

# Check nginx status
ssh indie@45.55.203.183 'sudo systemctl status nginx'
```

### Port Not Listening

```bash
# Check if app is listening on port 4000
ssh indie@45.55.203.183 'sudo netstat -tulpn | grep 4000'
```

### Can't SSH as indie User

```bash
# Login as root and check SSH keys
ssh root@45.55.203.183
cat /home/indie/.ssh/authorized_keys
# Ensure your public key is there

# Check permissions
ls -la /home/indie/.ssh
# Should be:
# drwx------ (700) for .ssh directory
# -rw------- (600) for authorized_keys file
```

---

## Maintenance

### View Application Logs

```bash
ssh indie@45.55.203.183 'sudo journalctl -u indie -f'
```

### Restart Service

```bash
ssh indie@45.55.203.183 'sudo systemctl restart indie'
```

### Stop Service

```bash
ssh indie@45.55.203.183 'sudo systemctl stop indie'
```

### Start Service

```bash
ssh indie@45.55.203.183 'sudo systemctl start indie'
```

### Backup Database

```bash
# Manual backup
ssh indie@45.55.203.183 'sudo cp /var/lib/indie/indie_prod.db /var/lib/indie/backups/indie_prod_$(date +%Y%m%d_%H%M%S).db'

# Set up automated daily backups with cron
ssh indie@45.55.203.183
sudo crontab -e -u indie
# Add this line:
0 2 * * * cp /var/lib/indie/indie_prod.db /var/lib/indie/backups/indie_prod_$(date +\%Y\%m\%d).db
```

### Delete Old Comments

Use the delete script on the server:

```bash
ssh indie@45.55.203.183
cd /opt/indie
sudo -u indie bash -c 'source /opt/indie/.env.prod && /opt/indie/bin/indie eval "File.cd!(\"/opt/indie\"); Code.eval_file(\"priv/scripts/delete_comment.exs\")"'
```

Or manually via IEx console:

```bash
ssh indie@45.55.203.183
sudo -u indie bash -c 'source /opt/indie/.env.prod && /opt/indie/bin/indie remote'
# Then in IEx:
# Indie.Comments.delete_comment(comment_id)
```

### Check SSL Certificate Status

```bash
ssh indie@45.55.203.183 'sudo certbot certificates'
```

### Manually Renew SSL Certificate

```bash
ssh indie@45.55.203.183 'sudo certbot renew'
```

### Check Disk Space

```bash
ssh indie@45.55.203.183 'df -h'
```

### Check Memory Usage

```bash
ssh indie@45.55.203.183 'free -m'
```

### Clean Old Backups

```bash
# Delete backups older than 30 days
ssh indie@45.55.203.183 'find /opt/indie/backups -type d -mtime +30 -exec rm -rf {} +'
```

---

## Monitoring

### Set Up Simple Uptime Monitoring

Consider using free services like:
- [UptimeRobot](https://uptimerobot.com) - Free tier monitors every 5 minutes
- [StatusCake](https://www.statuscake.com) - Free tier with basic monitoring
- [Pingdom](https://www.pingdom.com) - Free trial, then paid

Configure to ping: `https://glorifiednotepad.net`

### Email Alerts for Service Failures

For systemd failure notifications, you can set up email alerts, but that requires configuring sendmail/postfix which is beyond the scope of this guide.

---

## Quick Reference Commands

```bash
# Deploy new version
./deploy.sh production

# View logs
ssh indie@45.55.203.183 'sudo journalctl -u indie -f'

# Restart service
ssh indie@45.55.203.183 'sudo systemctl restart indie'

# Check status
ssh indie@45.55.203.183 'sudo systemctl status indie'

# Backup database
ssh indie@45.55.203.183 'sudo cp /var/lib/indie/indie_prod.db /var/lib/indie/backups/backup_$(date +%Y%m%d_%H%M%S).db'

# Check SSL certificate
ssh indie@45.55.203.183 'sudo certbot certificates'
```

---

## Support

If you run into issues:

1. Check the logs first: `sudo journalctl -u indie -xe`
2. Verify environment variables are set correctly in `/opt/indie/.env.prod`
3. Ensure file permissions are correct (files owned by `indie:indie`)
4. Check nginx is running and configured correctly
5. Verify DNS is pointing to the right IP

---

## Security Notes

- `.env.prod` contains secrets and should NEVER be committed to git
- SSH keys are used for secure deployment
- The systemd service runs as a non-root user (`indie`)
- SSL certificates are automatically renewed by certbot
- Consider setting up fail2ban for additional SSH security
- Keep Ubuntu and all packages up to date with `apt update && apt upgrade`
