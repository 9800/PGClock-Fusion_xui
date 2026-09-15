#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
PROJECT_DIR="/opt/PGCLOCK_XUI"
SERVICE_FILE="/etc/systemd/system/PGCLOCK_XUI.service"
REPO_URL="https://github.com/YOUR_USERNAME/YOUR_REPO.git" # <--- آدرس گیت‌هاب خود را اینجا بگذارید

[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: Please run with root privilege${NC}" && exit 1

install_dependencies() {
    echo "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt update && sudo apt install -y nodejs git
}

clone_project() {
    sudo rm -rf "$PROJECT_DIR"
    sudo git clone "$REPO_URL" "$PROJECT_DIR"
}

create_service() {
    cd "$PROJECT_DIR" && npm install
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=PGClock X-UI Service
After=network.target
[Service]
ExecStart=/usr/bin/node $PROJECT_DIR/server.js
Restart=always
User=root
WorkingDirectory=$PROJECT_DIR
[Install]
WantedBy=multi-user.target
EOL
    sudo systemctl daemon-reload
    sudo systemctl enable --now PGCLOCK_XUI
}

edit_config() { nano $PROJECT_DIR/pgclock.config && sudo systemctl restart PGCLOCK_XUI; }

menu() {
    clear
    echo "+---------------------------------------+"
    echo "| PGClock Fusion X-UI Installer         |"
    echo "+---------------------------------------+"
    echo -e "| 1. Install   | 2. Edit Config         |"
    echo -e "| 3. Uninstall | 0. Exit                |"
    echo "+---------------------------------------+"
    read -p "Choose an option: " choice
    case $choice in
        1) install_dependencies; clone_project; create_service; echo -e "${GREEN}Installed! Edit config now.${NC}"; edit_config ;;
        2) edit_config ;;
        3) sudo systemctl stop PGCLOCK_XUI && sudo rm -rf "$PROJECT_DIR" "$SERVICE_FILE" && sudo systemctl daemon-reload ;;
        0) exit 0 ;;
    esac
}
menu
