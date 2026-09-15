#!/bin/bash

# ==========================================
# PGClock Fusion X-UI - Smart Auto Installer
# Repo: https://github.com/9800/PGClock-Fusion_xui
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PROJECT_DIR="/opt/PGCLOCK_XUI"
SERVICE_FILE="/etc/systemd/system/PGCLOCK_XUI.service"
CONFIG_FILE="$PROJECT_DIR/pgclock.config"
REPO_RAW="https://raw.githubusercontent.com/9800/PGClock-Fusion_xui/main"

[[ $EUID -ne 0 ]] && echo -e "${RED}✗ Fatal error: Please run with root privilege${NC}" && exit 1

clear
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo -e "${BLUE}|   PGClock Fusion X-UI - Smart Auto Installer (3x-ui Detection)    |${NC}"
echo -e "${BLUE}|   Repo: github.com/9800/PGClock-Fusion_xui                        |${NC}"
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"

# ========== STEP 1: Install Dependencies ==========
install_dependencies() {
    echo -e "\n${YELLOW}[1/6] Installing dependencies...${NC}"
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq curl wget jq sqlite3 > /dev/null 2>&1
    
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
        apt-get install -y -qq nodejs > /dev/null 2>&1
    fi
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# ========== STEP 2: Auto-Detect 3x-ui Settings ==========
detect_xui_settings() {
    echo -e "\n${YELLOW}[2/6] Auto-detecting 3x-ui settings...${NC}"
    
    XUI_PORT="2053"
    XUI_PATH=""
    XUI_USER="admin"
    XUI_PASS="admin"
    XUI_HOST=$(curl -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    XUI_PROTOCOL="https"
    CERT_PUBLIC=""
    CERT_PRIVATE=""
    
    XUI_BIN=""
    XUI_DB=""
    XUI_CONFIG=""
    
    for path in "/usr/local/x-ui" "/opt/x-ui" "/usr/bin/x-ui" "/root/x-ui"; do
        if [ -d "$path" ]; then
            XUI_BIN="$path"
            break
        fi
    done
    
    if [ -n "$XUI_BIN" ]; then
        XUI_DB=$(find "$XUI_BIN" -name "*.db" 2>/dev/null | head -1)
        XUI_CONFIG=$(find "$XUI_BIN" -name "config.json" 2>/dev/null | head -1)
    fi
    
    if [ -z "$XUI_DB" ]; then
        XUI_DB=$(find /etc /usr/local /opt -name "x-ui.db" -o -name "xui.db" 2>/dev/null | head -1)
    fi
    if [ -z "$XUI_CONFIG" ]; then
        XUI_CONFIG=$(find /etc /usr/local /opt -name "config.json" -path "*x-ui*" 2>/dev/null | head -1)
    fi
    
    if [ -n "$XUI_CONFIG" ] && [ -f "$XUI_CONFIG" ]; then
        echo -e "  ${BLUE}→ Found config: $XUI_CONFIG${NC}"
        local conf_port=$(jq -r '.panelPort // .listen_port // empty' "$XUI_CONFIG" 2>/dev/null)
        local conf_path=$(jq -r '.basePath // .base_path // empty' "$XUI_CONFIG" 2>/dev/null)
        [ -n "$conf_port" ] && XUI_PORT="$conf_port"
        [ -n "$conf_path" ] && XUI_PATH="$conf_path"
    fi
    
    if [ -n "$XUI_DB" ] && [ -f "$XUI_DB" ]; then
        echo -e "  ${BLUE}→ Found database: $XUI_DB${NC}"
        
        local db_port=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='panelPort' OR key='listen_port' LIMIT 1;" 2>/dev/null)
        local db_path=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='basePath' OR key='base_path' OR key='webBasePath' LIMIT 1;" 2>/dev/null)
        local db_user=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='username' OR key='loginUsername' LIMIT 1;" 2>/dev/null)
        local db_pass=$(sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='password' OR key='loginPassword' LIMIT 1;" 2>/dev/null)
        
        [ -n "$db_port" ] && XUI_PORT="$db_port"
        [ -n "$db_path" ] && XUI_PATH="$db_path"
        [ -n "$db_user" ] && XUI_USER="$db_user"
        [ -n "$db_pass" ] && XUI_PASS="$db_pass"
    fi
    
    for cert_dir in "/root/cert" "/etc/letsencrypt/live" "/usr/local/x-ui/bin/cert" "/opt/x-ui/cert"; do
        if [ -d "$cert_dir" ]; then
            local domain_dir=$(find "$cert_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
            if [ -n "$domain_dir" ]; then
                if [ -f "$domain_dir/fullchain.pem" ] && [ -f "$domain_dir/privkey.pem" ]; then
                    CERT_PUBLIC="$domain_dir/fullchain.pem"
                    CERT_PRIVATE="$domain_dir/privkey.pem"
                    echo -e "  ${GREEN}✓ SSL certificates found: $domain_dir${NC}"
                    break
                fi
            fi
        fi
    done
    
    [ -n "$CERT_PUBLIC" ] && XUI_PROTOCOL="https" || XUI_PROTOCOL="http"
    
    if [ "$XUI_PROTOCOL" = "https" ] && [ "$XUI_PORT" = "443" ]; then
        SUB_BASE="https://$XUI_HOST"
    elif [ "$XUI_PROTOCOL" = "http" ] && [ "$XUI_PORT" = "80" ]; then
        SUB_BASE="http://$XUI_HOST"
    else
        SUB_BASE="$XUI_PROTOCOL://$XUI_HOST:$XUI_PORT"
    fi
    
    XUI_PATH=$(echo "$XUI_PATH" | sed 's|^/||;s|/$||')
    
    echo -e "\n${GREEN}✓ Detected 3x-ui Settings:${NC}"
    echo -e "  ${BLUE}Host:${NC}     $XUI_HOST"
    echo -e "  ${BLUE}Port:${NC}     $XUI_PORT"
    echo -e "  ${BLUE}Path:${NC}     ${XUI_PATH:-/ (root)}"
    echo -e "  ${BLUE}Protocol:${NC} $XUI_PROTOCOL"
    echo -e "  ${BLUE}SSL:${NC}      $([ -n "$CERT_PUBLIC" ] && echo "✓ Available" || echo "✗ Not found")"
    
    read -p "$(echo -e ${YELLOW}'[?] Are these settings correct? (Y/n): '${NC})" confirm
    confirm=${confirm:-Y}
    if [[ "$confirm" =~ ^[Nn] ]]; then
        read -p "  Host [$XUI_HOST]: " input_host
        [ -n "$input_host" ] && XUI_HOST="$input_host"
        
        read -p "  Port [$XUI_PORT]: " input_port
        [ -n "$input_port" ] && XUI_PORT="$input_port"
        
        read -p "  Path [$XUI_PATH]: " input_path
        [ -n "$input_path" ] && XUI_PATH="$input_path"
        
        read -p "  Username [$XUI_USER]: " input_user
        [ -n "$input_user" ] && XUI_USER="$input_user"
        
        read -s -p "  Password [$XUI_PASS]: " input_pass
        echo
        [ -n "$input_pass" ] && XUI_PASS="$input_pass"
    fi
}

# ========== STEP 3: Install Project ==========
install_project() {
    echo -e "\n${YELLOW}[3/6] Installing PGClock Fusion...${NC}"
    
    sudo rm -rf "$PROJECT_DIR"
    sudo mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR" || exit
    
    echo -e "  ${BLUE}→ Downloading server.js...${NC}"
    wget -q "$REPO_RAW/server.js" -O server.js
    
    echo -e "  ${BLUE}→ Downloading package.json...${NC}"
    wget -q "$REPO_RAW/package.json" -O package.json
    
    echo -e "  ${BLUE}→ Creating template directory...${NC}"
    mkdir -p "views/templates/default"
    wget -q "$REPO_RAW/views/templates/default/sub.ejs" -O "views/templates/default/sub.ejs"
    
    echo -e "  ${BLUE}→ Generating pgclock.config...${NC}"
    cat > "$CONFIG_FILE" << EOF
# ==========================================
# Auto-generated by PGClock Smart Installer
# ==========================================

PROTOCOL=$XUI_PROTOCOL
HOST=$XUI_HOST
PORT=$XUI_PORT
PATH=$XUI_PATH
USERNAME=$XUI_USER
PASSWORD=$XUI_PASS

SUBSCRIPTION=$SUB_BASE${XUI_PATH:+/$XUI_PATH}/sub/

$([ -n "$CERT_PUBLIC" ] && echo "PUBLIC_KEY_PATH=$CERT_PUBLIC" || echo "#PUBLIC_KEY_PATH=")
$([ -n "$CERT_PRIVATE" ] && echo "PRIVATE_KEY_PATH=$CERT_PRIVATE" || echo "#PRIVATE_KEY_PATH=")

Backup_link=
SUB_HTTP_PORT=2082
SUB_HTTPS_PORT=2083
TEMPLATE_NAME=default
BRAND_NAME=PGClock Fusion X-UI
BRAND_LOGO=
TELEGRAM_URL=
WHATSAPP_URL=
TWO_FACTOR=false
TOTP_SECRET=
EOF

    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓ Project files installed${NC}"
}

# ========== STEP 4: Install Node Dependencies ==========
install_node_deps() {
    echo -e "\n${YELLOW}[4/6] Installing Node.js dependencies...${NC}"
    cd "$PROJECT_DIR" || exit
    npm install --production > /dev/null 2>&1
    echo -e "${GREEN}✓ Node dependencies installed${NC}"
}

# ========== STEP 5: Create Systemd Service ==========
create_service() {
    echo -e "\n${YELLOW}[5/6] Creating systemd service...${NC}"
    
    systemctl stop PGCLOCK_XUI 2>/dev/null
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PGClock Fusion X-UI Service
After=network.target

[Service]
ExecStart=/usr/bin/node $PROJECT_DIR/server.js
Restart=always
User=root
Group=root
Environment=NODE_ENV=production
WorkingDirectory=$PROJECT_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable PGCLOCK_XUI > /dev/null 2>&1
    systemctl start PGCLOCK_XUI
    echo -e "${GREEN}✓ Service created and started${NC}"
}

# ========== STEP 6: Verify & Configure Panel ==========
configure_panel() {
    echo -e "\n${YELLOW}[6/6] Configuring 3x-ui panel...${NC}"
    
    local sub_template="$SUB_BASE:2082/sub/YOUR_USER_SUB_ID"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✓ Installation completed successfully!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}📋 Service Status:${NC}"
    systemctl status PGCLOCK_XUI --no-pager -l | head -5
    
    echo -e "\n${BLUE}🔗 Template Subscription URL:${NC}"
    echo -e "  ${YELLOW}$sub_template${NC}"
    
    echo -e "\n${BLUE}📱 How to configure in 3x-ui:${NC}"
    echo -e "  1. Open your 3x-ui panel"
    echo -e "  2. Go to ${YELLOW}Inbounds${NC}"
    echo -e "  3. For each inbound, click ${YELLOW}Edit${NC}"
    echo -e "  4. Find ${YELLOW}Subscription URL${NC} field"
    echo -e "  5. Replace it with:"
    echo -e "     ${GREEN}$SUB_BASE:2082/sub/\${user.subId}${NC}"
    
    echo -e "\n${BLUE}📊 Ports opened:${NC}"
    echo -e "  ${GREEN}HTTP:  $XUI_HOST:2082${NC}"
    [ -n "$CERT_PUBLIC" ] && echo -e "  ${GREEN}HTTPS: $XUI_HOST:2083${NC}"
    
    echo -e "\n${BLUE}🛠  Management Commands:${NC}"
    echo -e "  ${YELLOW}systemctl status PGCLOCK_XUI${NC}   - Check status"
    echo -e "  ${YELLOW}systemctl restart PGCLOCK_XUI${NC}  - Restart service"
    echo -e "  ${YELLOW}journalctl -u PGCLOCK_XUI -f${NC}   - View logs"
    echo -e "  ${YELLOW}nano $CONFIG_FILE${NC}  - Edit config"
    
    echo -e "\n${YELLOW}⚠️  Important:${NC} Make sure ports ${GREEN}2082${NC} and ${GREEN}2083${NC} are open in your firewall."
    
    if command -v ufw &> /dev/null; then
        read -p "$(echo -e ${YELLOW}'[?] Open ports 2082/2083 in UFW firewall? (Y/n): '${NC})" open_fw
        if [[ ! "$open_fw" =~ ^[Nn] ]]; then
            ufw allow 2082/tcp > /dev/null 2>&1
            ufw allow 2083/tcp > /dev/null 2>&1
            echo -e "${GREEN}✓ Firewall ports opened${NC}"
        fi
    fi
}

# ========== Uninstall ==========
uninstall_project() {
    echo -e "\n${RED}Uninstalling PGClock Fusion...${NC}"
    systemctl stop PGCLOCK_XUI 2>/dev/null
    systemctl disable PGCLOCK_XUI 2>/dev/null
    sudo rm -rf "$PROJECT_DIR"
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    echo -e "${GREEN}✓ Uninstalled${NC}"
}

# ========== Reinstall / Update ==========
update_project() {
    echo -e "\n${YELLOW}Updating PGClock Fusion...${NC}"
    systemctl stop PGCLOCK_XUI 2>/dev/null
    cd "$PROJECT_DIR" || exit
    
    cp "$CONFIG_FILE" /tmp/pgclock.config.bak
    
    wget -q "$REPO_RAW/server.js" -O server.js
    wget -q "$REPO_RAW/package.json" -O package.json
    mkdir -p "views/templates/default"
    wget -q "$REPO_RAW/views/templates/default/sub.ejs" -O "views/templates/default/sub.ejs"
    
    npm install --production > /dev/null 2>&1
    
    mv /tmp/pgclock.config.bak "$CONFIG_FILE"
    
    systemctl start PGCLOCK_XUI
    echo -e "${GREEN}✓ Updated successfully${NC}"
}

# ========== Main Menu ==========
show_menu() {
    clear
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    echo -e "${BLUE}|        PGClock Fusion X-UI - Smart Management Menu                |${NC}"
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    echo -e "  ${GREEN}1.${NC} Install PGClock Fusion (Auto-detect 3x-ui)"
    echo -e "  ${GREEN}2.${NC} Update PGClock Fusion"
    echo -e "  ${GREEN}3.${NC} Edit Configuration"
    echo -e "  ${GREEN}4.${NC} View Service Status"
    echo -e "  ${GREEN}5.${NC} View Logs"
    echo -e "  ${GREEN}6.${NC} Uninstall"
    echo -e "  ${GREEN}0.${NC} Exit"
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    
    read -p "$(echo -e ${YELLOW}'Choose an option: '${NC})" choice
    
    case $choice in
        1)
            install_dependencies
            detect_xui_settings
            install_project
            install_node_deps
            create_service
            configure_panel
            ;;
        2) update_project ;;
        3) nano "$CONFIG_FILE" && systemctl restart PGCLOCK_XUI && echo -e "${GREEN}✓ Config updated${NC}" ;;
        4) systemctl status PGCLOCK_XUI --no-pager ;;
        5) journalctl -u PGCLOCK_XUI -n 50 --no-pager ;;
        6) uninstall_project ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    show_menu
}

# ========== Run ==========
if [ "$1" = "install" ]; then
    install_dependencies
    detect_xui_settings
    install_project
    install_node_deps
    create_service
    configure_panel
else
    show_menu
fi
