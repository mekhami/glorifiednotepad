#!/bin/bash
# Quick deployment helper script

case "$1" in
  deploy)
    echo "Deploying to production..."
    ./deploy.sh production
    ;;
  logs)
    echo "Viewing application logs..."
    ssh indie@45.55.203.183 'sudo journalctl -u indie -f'
    ;;
  status)
    echo "Checking service status..."
    ssh indie@45.55.203.183 'sudo systemctl status indie'
    ;;
  restart)
    echo "Restarting service..."
    ssh indie@45.55.203.183 'sudo systemctl restart indie'
    ;;
  stop)
    echo "Stopping service..."
    ssh indie@45.55.203.183 'sudo systemctl stop indie'
    ;;
  start)
    echo "Starting service..."
    ssh indie@45.55.203.183 'sudo systemctl start indie'
    ;;
  backup)
    echo "Backing up database..."
    ssh indie@45.55.203.183 'sudo cp /var/lib/indie/indie_prod.db /var/lib/indie/backups/indie_prod_$(date +%Y%m%d_%H%M%S).db'
    echo "Database backed up!"
    ;;
  ssh)
    echo "Connecting to server..."
    ssh indie@45.55.203.183
    ;;
  nginx-logs)
    echo "Viewing nginx logs..."
    ssh indie@45.55.203.183 'sudo tail -f /var/log/nginx/glorifiednotepad_error.log'
    ;;
  seed-logo)
    echo "Running seed logo script..."
    ssh indie@45.55.203.183 'bash /opt/indie-repo/deployment/seed_logo.sh'
    ;;
  seed-logo-cron)
    echo "Installing daily cron job for seed logo at 6:00 AM..."
    ssh indie@45.55.203.183 '(crontab -l 2>/dev/null | grep -v seed_logo; echo "0 6 * * * /opt/indie-repo/deployment/seed_logo.sh >> /var/log/indie/seed_logo.log 2>&1") | crontab -'
    echo "Done. Logo will re-seed daily at 6:00 AM."
    ;;
  *)
    echo "Usage: $0 {deploy|logs|status|restart|stop|start|backup|ssh|nginx-logs|seed-logo|seed-logo-cron}"
    echo ""
    echo "Commands:"
    echo "  deploy          - Build and deploy to production"
    echo "  logs            - View application logs"
    echo "  status          - Check service status"
    echo "  restart         - Restart the service"
    echo "  stop            - Stop the service"
    echo "  start           - Start the service"
    echo "  backup          - Backup the database"
    echo "  ssh             - SSH into the server"
    echo "  nginx-logs      - View nginx error logs"
    echo "  seed-logo       - Run the seed logo script now"
    echo "  seed-logo-cron  - Install a daily cron job (6 AM) for seed logo"
    exit 1
    ;;
esac
