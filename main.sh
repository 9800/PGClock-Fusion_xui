#!/bin/bash

# ==========================================
# PGClock Fusion X-UI - Secure Auto Installer
# Repo: https://github.com/9800/PGClock-Fusion_xui
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PROJECT_DIR="/opt/PGCLOCK_XUI"
SERVICE_FILE="/etc/systemd/system/PGCLOCK_XUI.service"
CONFIG_FILE="$PROJECT_DIR/pgclock.config"
ENV_FILE="$PROJECT_DIR/.env.credentials"
REPO_RAW="https://raw.githubusercontent.com/9800/PGClock-Fusion_xui/main"

[[ $EUID -ne 0 ]] && echo -e "${RED}✗ Fatal error: Please run with root privilege${NC}" && exit 1

clear
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo -e "${BLUE}|   PGClock Fusion X-UI - Secure Auto Installer                     |${NC}"
echo -e "${BLUE}|   Repo: github.com/9800/PGClock-Fusion_xui                        |${NC}"
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"

# ========== Helper Functions ==========
read_setting() {
    sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='$1' LIMIT 1;" 2>/dev/null
}

# ========== STEP 1: Install Dependencies ==========
install_dependencies() {
    echo -e "\n${YELLOW}[1/7] Installing dependencies...${NC}"
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq curl wget jq sqlite3 net-tools > /dev/null 2>&1
    
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
        apt-get install -y -qq nodejs > /dev/null 2>&1
    fi
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# ========== STEP 2: Find 3x-ui Database ==========
find_database() {
    echo -e "\n${YELLOW}[2/7] Finding 3x-ui database...${NC}"
    
    XUI_DB=""
    for db_path in "/etc/x-ui/x-ui.db" "/usr/local/x-ui/bin/x-ui.db" "/usr/local/x-ui/x-ui.db" "/opt/x-ui/bin/x-ui.db" "/opt/x-ui/x-ui.db" "/root/x-ui/x-ui.db"; do
        if [ -f "$db_path" ]; then
            XUI_DB="$db_path"
            break
        fi
    done
    
    if [ -z "$XUI_DB" ]; then
        XUI_DB=$(find /etc /usr/local /opt /root -name "x-ui.db" -o -name "xui.db" 2>/dev/null | head -1)
    fi
    
    if [ -z "$XUI_DB" ]; then
        echo -e "  ${RED}✗ 3x-ui database not found!${NC}"
        echo -e "  ${YELLOW}Please install 3x-ui first.${NC}"
        exit 1
    fi
    
    echo -e "  ${GREEN}✓ Found database: $XUI_DB${NC}"
}

# ========== STEP 3: Auto-Detect Settings ==========
detect_settings() {
    echo -e "\n${YELLOW}[3/7] Reading settings from database...${NC}"
    
    # Default values
    WEB_PORT="2053"
    WEB_BASE_PATH=""
    WEB_DOMAIN=$(curl -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    WEB_CERT=""
    WEB_KEY=""
    
    # Subscription settings
    SUB_PORT=""
    SUB_PATH="/sub/"
    SUB_URI=""
    SUB_TITLE=""
    SUB_SUPPORT_URL=""
    SUB_PROFILE_URL=""
    SUB_ANNOUNCE=""
    SUB_LISTEN=""
    SUB_DOMAIN=""
    SUB_CERT=""
    SUB_KEY=""
    SUB_ENABLE=""
    
    # Credentials
    PANEL_USER=""
    PANEL_PASS=""
    
    # Read panel settings
    local db_web_port=$(read_setting "webPort")
    local db_web_base_path=$(read_setting "webBasePath")
    local db_web_domain=$(read_setting "webDomain")
    local db_web_cert=$(read_setting "webCertFile")
    local db_web_key=$(read_setting "webKeyFile")
    
    [ -n "$db_web_port" ] && WEB_PORT="$db_web_port"
    [ -n "$db_web_base_path" ] && WEB_BASE_PATH="$db_web_base_path"
    [ -n "$db_web_domain" ] && WEB_DOMAIN="$db_web_domain"
    [ -n "$db_web_cert" ] && WEB_CERT="$db_web_cert"
    [ -n "$db_web_key" ] && WEB_KEY="$db_web_key"
    
    # Read subscription settings
    local db_sub_enable=$(read_setting "subEnable")
    local db_sub_port=$(read_setting "subPort")
    local db_sub_path=$(read_setting "subPath")
    local db_sub_uri=$(read_setting "subURI")
    local db_sub_title=$(read_setting "subTitle")
    local db_sub_support=$(read_setting "subSupportUrl")
    local db_sub_profile=$(read_setting "subProfileUrl")
    local db_sub_announce=$(read_setting "subAnnounce")
    local db_sub_listen=$(read_setting "subListen")
    local db_sub_domain=$(read_setting "subDomain")
    local db_sub_cert=$(read_setting "subCertFile")
    local db_sub_key=$(read_setting "subKeyFile")
    
    [ -n "$db_sub_enable" ] && SUB_ENABLE="$db_sub_enable"
    [ -n "$db_sub_port" ] && SUB_PORT="$db_sub_port"
    [ -n "$db_sub_path" ] && SUB_PATH="$db_sub_path"
    [ -n "$db_sub_uri" ] && SUB_URI="$db_sub_uri"
    [ -n "$db_sub_title" ] && SUB_TITLE="$db_sub_title"
    [ -n "$db_sub_support" ] && SUB_SUPPORT_URL="$db_sub_support"
    [ -n "$db_sub_profile" ] && SUB_PROFILE_URL="$db_sub_profile"
    [ -n "$db_sub_announce" ] && SUB_ANNOUNCE="$db_sub_announce"
    [ -n "$db_sub_listen" ] && SUB_LISTEN="$db_sub_listen"
    [ -n "$db_sub_domain" ] && SUB_DOMAIN="$db_sub_domain"
    [ -n "$db_sub_cert" ] && SUB_CERT="$db_sub_cert"
    [ -n "$db_sub_key" ] && SUB_KEY="$db_sub_key"
    
    # Read credentials
    PANEL_USER=$(sqlite3 "$XUI_DB" "SELECT username FROM users ORDER BY id LIMIT 1;" 2>/dev/null)
    
    # Set defaults
    [ -z "$SUB_PORT" ] && SUB_PORT="$WEB_PORT"
    [ -z "$SUB_DOMAIN" ] && SUB_DOMAIN="$WEB_DOMAIN"
    
    # Clean paths
    WEB_BASE_PATH=$(echo "$WEB_BASE_PATH" | sed 's|^/||;s|/$||')
    SUB_PATH=$(echo "$SUB_PATH" | sed 's|^/||;s|/$||')
    
    # Determine protocol
    SUB_PROTOCOL="http"
    if [ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && [ -n "$SUB_KEY" ] && [ -f "$SUB_KEY" ]; then
        SUB_PROTOCOL="https"
    fi
    
    # Build base URL
    if [ "$SUB_PROTOCOL" = "https" ]; then
        [ "$SUB_PORT" = "443" ] && SUB_BASE="https://$SUB_DOMAIN" || SUB_BASE="https://$SUB_DOMAIN:$SUB_PORT"
    else
        [ "$SUB_PORT" = "80" ] && SUB_BASE="http://$SUB_DOMAIN" || SUB_BASE="http://$SUB_DOMAIN:$SUB_PORT"
    fi
    
    # Display detected settings
    echo -e "\n${GREEN}✓ Detected Settings from Database:${NC}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}Panel:${NC}"
    echo -e "    Port: $WEB_PORT | Path: ${WEB_BASE_PATH:-/} | Domain: $WEB_DOMAIN"
    echo -e ""
    echo -e "  ${BLUE}Subscription:${NC}"
    echo -e "    Port: ${GREEN}$SUB_PORT${NC} | Path: ${GREEN}$SUB_PATH${NC} | Domain: ${GREEN}$SUB_DOMAIN${NC}"
    echo -e "    Title: ${GREEN}${SUB_TITLE:-Not set}${NC}"
    echo -e "    Support URL: ${GREEN}${SUB_SUPPORT_URL:-Not set}${NC}"
    echo -e "    Profile URL: ${GREEN}${SUB_PROFILE_URL:-Not set}${NC}"
    echo -e "    Announce: ${GREEN}${SUB_ANNOUNCE:-Not set}${NC}"
    echo -e "    SSL: $([ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && echo "${GREEN}✓ Enabled${NC}" || echo "${YELLOW}✗ Disabled${NC}")"
    echo -e "    Status: $([ "$SUB_ENABLE" = "true" ] || [ "$SUB_ENABLE" = "1" ] && echo "${GREEN}Enabled${NC}" || echo "${YELLOW}Disabled${NC}")"
    echo -e ""
    echo -e "  ${BLUE}Credentials:${NC}"
    echo -e "    Username: ${GREEN}$PANEL_USER${NC}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Disable 3x-ui subscription server (replace it)
    disable_xui_subscription
}

# ========== STEP 4: Disable 3x-ui Subscription Server ==========
disable_xui_subscription() {
    echo -e "\n${YELLOW}[4/7] Preparing subscription server...${NC}"
    
    if [ "$SUB_ENABLE" = "true" ] || [ "$SUB_ENABLE" = "1" ]; then
        echo -e "  ${YELLOW}→ Disabling 3x-ui's built-in subscription server...${NC}"
        
        # Disable 3x-ui's built-in subscription server
        sqlite3 "$XUI_DB" "UPDATE settings SET value='false' WHERE key='subEnable';" 2>/dev/null
        
        echo -e "  ${GREEN}✓ 3x-ui subscription server disabled${NC}"
        echo -e "  ${GREEN}✓ Port $SUB_PORT is now available${NC}"
        
        # Restart 3x-ui to apply changes
        echo -e "  ${YELLOW}→ Restarting 3x-ui to free the port...${NC}"
        systemctl restart x-ui 2>/dev/null
        sleep 2
        echo -e "  ${GREEN}✓ 3x-ui restarted${NC}"
    else
        echo -e "  ${GREEN}✓ 3x-ui subscription server is already disabled${NC}"
    fi
    
    echo -e ""
    echo -e "  ${GREEN}✓ PGClock will now run on port $SUB_PORT${NC}"
    echo -e "  ${GREEN}✓ Same port as 3x-ui's subscription server${NC}"
    echo -e "  ${GREEN}✓ No port change needed${NC}"
}

# ========== STEP 5: Get Password Securely ==========
get_password() {
    echo -e "\n${YELLOW}[5/7] Setting up secure credentials...${NC}"
    
    if [ -z "$PANEL_USER" ]; then
        read -p "  Panel Username: " PANEL_USER
    fi
    
    echo -e "  ${BLUE}Username:${NC} ${GREEN}$PANEL_USER${NC}"
    echo -e "  ${YELLOW}⚠ Password will be stored securely (not in config file)${NC}"
    read -s -p "  Enter panel password: " PANEL_PASS
    echo
    
    if [ -z "$PANEL_PASS" ]; then
        echo -e "  ${RED}✗ Password cannot be empty${NC}"
        get_password
    fi
}

# ========== STEP 6: Install Project ==========
install_project() {
    echo -e "\n${YELLOW}[6/7] Installing PGClock Fusion...${NC}"
    
    sudo rm -rf "$PROJECT_DIR"
    sudo mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR" || exit
    
    echo -e "  ${BLUE}→ Downloading files from GitHub...${NC}"
    wget -q "$REPO_RAW/server.js" -O server.js
    wget -q "$REPO_RAW/package.json" -O package.json
    mkdir -p "views/templates/default"
    wget -q "$REPO_RAW/views/templates/default/sub.ejs" -O "views/templates/default/sub.ejs"
    
    local sub_url="$SUB_BASE/${SUB_PATH}/"
    
    echo -e "  ${BLUE}→ Generating config (without password)...${NC}"
    cat > "$CONFIG_FILE" << EOF
# ==========================================
# Auto-generated by PGClock Secure Installer
# Source: github.com/9800/PGClock-Fusion_xui
# ==========================================

PROTOCOL=$SUB_PROTOCOL
HOST=$SUB_DOMAIN
PORT=$WEB_PORT
PATH=$WEB_BASE_PATH
USERNAME=$PANEL_USER

SUBSCRIPTION=$sub_url

$([ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && echo "PUBLIC_KEY_PATH=$SUB_CERT" || echo "#PUBLIC_KEY_PATH=")
$([ -n "$SUB_KEY" ] && [ -f "$SUB_KEY" ] && echo "PRIVATE_KEY_PATH=$SUB_KEY" || echo "#PRIVATE_KEY_PATH=")

Backup_link=
SUB_HTTP_PORT=$SUB_PORT
$([ "$SUB_PROTOCOL" = "https" ] && echo "SUB_HTTPS_PORT=$SUB_PORT" || echo "#SUB_HTTPS_PORT=")

TEMPLATE_NAME=default
BRAND_NAME=${SUB_TITLE:-PGClock Fusion X-UI}
BRAND_LOGO=
TELEGRAM_URL=${SUB_SUPPORT_URL:-}
WHATSAPP_URL=
SUPPORT_URL=${SUB_SUPPORT_URL:-}
PROFILE_URL=${SUB_PROFILE_URL:-}
ANNOUNCE=${SUB_ANNOUNCE:-}
TWO_FACTOR=false
TOTP_SECRET=
EOF

    # Create secure environment file for password
    echo -e "  ${BLUE}→ Creating secure credentials file...${NC}"
    cat > "$ENV_FILE" << EOF
PANEL_PASSWORD=$PANEL_PASS
EOF
    
    # Set strict permissions (only root can read)
    chmod 600 "$ENV_FILE"
    chmod 600 "$CONFIG_FILE"
    
    # Clear password from memory
    PANEL_PASS=""
    
    echo -e "${GREEN}✓ Project files installed${NC}"
    echo -e "  ${GREEN}✓ Credentials stored securely in: $ENV_FILE${NC}"
}

# ========== STEP 7: Install Node Dependencies & Create Service ==========
install_node_deps() {
    echo -e "\n${YELLOW}[7/7] Starting services...${NC}"
    cd "$PROJECT_DIR" || exit
    npm install --production > /dev/null 2>&1
    
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
EnvironmentFile=$ENV_FILE
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

# ========== STEP 8: Show Results ==========
show_results() {
    local sub_url="$SUB_BASE/${SUB_PATH}/{user.subId}"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✓ Installation completed successfully!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}📋 Service Status:${NC}"
    systemctl status PGCLOCK_XUI --no-pager -l | head -5
    
    echo -e "\n${BLUE}🔗 Subscription URL:${NC}"
    echo -e "  ${GREEN}$sub_url${NC}"
    
    echo -e "\n${BLUE}📊 Settings imported from 3x-ui:${NC}"
    echo -e "  ${GREEN}subPort${NC}:        $SUB_PORT ${YELLOW}(unchanged)${NC}"
    echo -e "  ${GREEN}subPath${NC}:        $SUB_PATH"
    echo -e "  ${GREEN}subTitle${NC}:       ${SUB_TITLE:-Not set}"
    echo -e "  ${GREEN}subSupportUrl${NC}: ${SUB_SUPPORT_URL:-Not set}"
    echo -e "  ${GREEN}subProfileUrl${NC}: ${SUB_PROFILE_URL:-Not set}"
    echo -e "  ${GREEN}subAnnounce${NC}:   ${SUB_ANNOUNCE:-Not set}"
    
    echo -e "\n${BLUE}🔐 Security:${NC}"
    echo -e "  ${GREEN}✓ Password NOT stored in config file${NC}"
    echo -e "  ${GREEN}✓ Credentials stored in: $ENV_FILE${NC}"
    echo -e "  ${GREEN}✓ File permissions: 600 (root only)${NC}"
    
    echo -e "\n${BLUE}🛠  Management:${NC}"
    echo -e "  ${YELLOW}systemctl status PGCLOCK_XUI${NC}"
    echo -e "  ${YELLOW}systemctl restart PGCLOCK_XUI${NC}"
    echo -e "  ${YELLOW}journalctl -u PGCLOCK_XUI -f${NC}"
    echo -e "  ${YELLOW}nano $CONFIG_FILE${NC}"
    
    if command -v ufw &> /dev/null; then
        read -p "$(echo -e ${YELLOW}'[?] Open port $SUB_PORT in UFW? (Y/n): '${NC})" open_fw
        if [[ ! "$open_fw" =~ ^[Nn] ]]; then
            ufw allow "$SUB_PORT/tcp" > /dev/null 2>&1
            echo -e "${GREEN}✓ Firewall port opened${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}🎯 What happened:${NC}"
    echo -e "  ${YELLOW}1.${NC} 3x-ui's subscription server was ${GREEN}disabled${NC}"
    echo -e "  ${YELLOW}2.${NC} PGClock template is now running on ${GREEN}port $SUB_PORT${NC}"
    echo -e "  ${YELLOW}3.${NC} ${GREEN}Same port${NC} as before - no change!"
    echo -e "  ${YELLOW}4.${NC} Users will see the new PGClock template"
}

# ========== Uninstall ==========
uninstall_project() {
    echo -e "\n${RED}Uninstalling PGClock Fusion...${NC}"
    systemctl stop PGCLOCK_XUI 2>/dev/null
    systemctl disable PGCLOCK_XUI 2>/dev/null
    sudo rm -rf "$PROJECT_DIR"
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    
    # Re-enable 3x-ui subscription server
    if [ -n "$XUI_DB" ]; then
        echo -e "  ${YELLOW}→ Re-enabling 3x-ui subscription server...${NC}"
        sqlite3 "$XUI_DB" "UPDATE settings SET value='true' WHERE key='subEnable';" 2>/dev/null
        systemctl restart x-ui 2>/dev/null
        echo -e "  ${GREEN}✓ 3x-ui subscription server re-enabled${NC}"
    fi
    
    echo -e "${GREEN}✓ Uninstalled${NC}"
}

# ========== Update ==========
update_project() {
    echo -e "\n${YELLOW}Updating PGClock Fusion...${NC}"
    systemctl stop PGCLOCK_XUI 2>/dev/null
    cd "$PROJECT_DIR" || exit
    
    cp "$CONFIG_FILE" /tmp/pgclock.config.bak
    [ -f "$ENV_FILE" ] && cp "$ENV_FILE" /tmp/pgclock.env.bak
    
    wget -q "$REPO_RAW/server.js" -O server.js
    wget -q "$REPO_RAW/package.json" -O package.json
    mkdir -p "views/templates/default"
    wget -q "$REPO_RAW/views/templates/default/sub.ejs" -O "views/templates/default/sub.ejs"
    
    npm install --production > /dev/null 2>&1
    
    mv /tmp/pgclock.config.bak "$CONFIG_FILE"
    [ -f /tmp/pgclock.env.bak ] && mv /tmp/pgclock.env.bak "$ENV_FILE"
    
    systemctl start PGCLOCK_XUI
    echo -e "${GREEN}✓ Updated successfully${NC}"
}

# ========== Main Menu ==========
show_menu() {
    clear
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    echo -e "${BLUE}|        PGClock Fusion X-UI - Management Menu                      |${NC}"
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    echo -e "  ${GREEN}1.${NC} Install PGClock Fusion"
    echo -e "  ${GREEN}2.${NC} Update PGClock Fusion"
    echo -e "  ${GREEN}3.${NC} Edit Configuration"
    echo -e "  ${GREEN}4.${NC} Edit Credentials"
    echo -e "  ${GREEN}5.${NC} View Service Status"
    echo -e "  ${GREEN}6.${NC} View Logs"
    echo -e "  ${GREEN}7.${NC} Uninstall (re-enable 3x-ui subscription)"
    echo -e "  ${GREEN}0.${NC} Exit"
    echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
    
    read -p "$(echo -e ${YELLOW}'Choose an option: '${NC})" choice
    
    case $choice in
        1)
            install_dependencies
            find_database
            detect_settings
            get_password
            install_project
            install_node_deps
            show_results
            ;;
        2) update_project ;;
        3) nano "$CONFIG_FILE" && systemctl restart PGCLOCK_XUI && echo -e "${GREEN}✓ Config updated${NC}" ;;
        4) nano "$ENV_FILE" && systemctl restart PGCLOCK_XUI && echo -e "${GREEN}✓ Credentials updated${NC}" ;;
        5) systemctl status PGCLOCK_XUI --no-pager ;;
        6) journalctl -u PGCLOCK_XUI -n 50 --no-pager ;;
        7) uninstall_project ;;
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
    find_database
    detect_settings
    get_password
    install_project
    install_node_deps
    show_results
else
    show_menu
fi
