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
  *)
    echo "Usage: $0 {deploy|logs|status|restart|stop|start|backup|ssh|nginx-logs}"
    echo ""
    echo "Commands:"
    echo "  deploy      - Build and deploy to production"
    echo "  logs        - View application logs"
    echo "  status      - Check service status"
    echo "  restart     - Restart the service"
    echo "  stop        - Stop the service"
    echo "  start       - Start the service"
    echo "  backup      - Backup the database"
    echo "  ssh         - SSH into the server"
    echo "  nginx-logs  - View nginx error logs"
    exit 1
    ;;
esac
