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
    echo -e "\n${YELLOW}[2/6] Auto-detecting 3x-ui settings from database...${NC}"
    
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
    
    # Credentials
    PANEL_USER=""
    PANEL_PASS=""
    
    # Find 3x-ui database
    XUI_DB=""
    for db_path in "/etc/x-ui/x-ui.db" "/usr/local/x-ui/bin/x-ui.db" "/usr/local/x-ui/x-ui.db" "/opt/x-ui/bin/x-ui.db" "/opt/x-ui/x-ui.db" "/root/x-ui/x-ui.db"; do
        if [ -f "$db_path" ]; then
            XUI_DB="$db_path"
            echo -e "  ${BLUE}→ Found database: $XUI_DB${NC}"
            break
        fi
    done
    
    # Fallback search
    if [ -z "$XUI_DB" ]; then
        XUI_DB=$(find /etc /usr/local /opt /root -name "x-ui.db" -o -name "xui.db" 2>/dev/null | head -1)
        if [ -n "$XUI_DB" ]; then
            echo -e "  ${BLUE}→ Found database (search): $XUI_DB${NC}"
        fi
    fi
    
    if [ -z "$XUI_DB" ]; then
        echo -e "  ${RED}✗ 3x-ui database not found!${NC}"
        echo -e "  ${YELLOW}Please make sure 3x-ui is installed first.${NC}"
        exit 1
    fi
    
    # ============================================
    # READ ALL SETTINGS FROM DATABASE
    # ============================================
    echo -e "  ${BLUE}→ Reading settings from database...${NC}"
    
    # Helper function to read a setting
    read_setting() {
        sqlite3 "$XUI_DB" "SELECT value FROM settings WHERE key='$1' LIMIT 1;" 2>/dev/null
    }
    
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
    
    # ============================================
    # READ SUBSCRIPTION SETTINGS (ALL OF THEM!)
    # ============================================
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
    
    # Read credentials from users table
    PANEL_USER=$(sqlite3 "$XUI_DB" "SELECT username FROM users ORDER BY id LIMIT 1;" 2>/dev/null)
    
    # Determine effective values
    if [ -z "$SUB_PORT" ]; then
        SUB_PORT="$WEB_PORT"
        echo -e "  ${YELLOW}⚠ subPort not set in database, using webPort: $SUB_PORT${NC}"
    fi
    
    if [ -z "$SUB_DOMAIN" ]; then
        if [ -n "$WEB_DOMAIN" ]; then
            SUB_DOMAIN="$WEB_DOMAIN"
        fi
    fi
    
    # Clean paths
    WEB_BASE_PATH=$(echo "$WEB_BASE_PATH" | sed 's|^/||;s|/$||')
    SUB_PATH=$(echo "$SUB_PATH" | sed 's|^/||;s|/$||')
    SUB_URI=$(echo "$SUB_URI" | sed 's|^/||;s|/$||')
    
    # Determine protocol based on SSL certificates
    SUB_PROTOCOL="http"
    if [ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && [ -n "$SUB_KEY" ] && [ -f "$SUB_KEY" ]; then
        SUB_PROTOCOL="https"
    fi
    
    # Build subscription base URL
    if [ "$SUB_PROTOCOL" = "https" ]; then
        if [ "$SUB_PORT" = "443" ]; then
            SUB_BASE="https://$SUB_DOMAIN"
        else
            SUB_BASE="https://$SUB_DOMAIN:$SUB_PORT"
        fi
    else
        if [ "$SUB_PORT" = "80" ]; then
            SUB_BASE="http://$SUB_DOMAIN"
        else
            SUB_BASE="http://$SUB_DOMAIN:$SUB_PORT"
        fi
    fi
    
    # Display detected settings
    echo -e "\n${GREEN}✓ Detected 3x-ui Settings from Database:${NC}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}Panel Settings:${NC}"
    echo -e "    Web Port:      ${GREEN}$WEB_PORT${NC}"
    echo -e "    Web Base Path: ${GREEN}${WEB_BASE_PATH:-/ (root)}${NC}"
    echo -e "    Web Domain:    ${GREEN}$WEB_DOMAIN${NC}"
    echo -e "    Panel SSL:     $([ -n "$WEB_CERT" ] && [ -f "$WEB_CERT" ] && echo "${GREEN}✓ $WEB_CERT${NC}" || echo "${YELLOW}✗ Not configured${NC}")"
    echo -e ""
    echo -e "  ${BLUE}Subscription Settings:${NC}"
    echo -e "    Sub Port:      ${GREEN}$SUB_PORT${NC} ${YELLOW}← subPort${NC}"
    echo -e "    Sub Path:      ${GREEN}$SUB_PATH${NC} ${YELLOW}← subPath${NC}"
    echo -e "    Sub URI:       ${GREEN}${SUB_URI:-$SUB_PATH}${NC} ${YELLOW}← subURI${NC}"
    echo -e "    Sub Title:     ${GREEN}${SUB_TITLE:-Not set}${NC} ${YELLOW}← subTitle${NC}"
    echo -e "    Sub Domain:    ${GREEN}$SUB_DOMAIN${NC} ${YELLOW}← subDomain${NC}"
    echo -e "    Support URL:   ${GREEN}${SUB_SUPPORT_URL:-Not set}${NC} ${YELLOW}← subSupportUrl${NC}"
    echo -e "    Profile URL:   ${GREEN}${SUB_PROFILE_URL:-Not set}${NC} ${YELLOW}← subProfileUrl${NC}"
    echo -e "    Announce:      ${GREEN}${SUB_ANNOUNCE:-Not set}${NC} ${YELLOW}← subAnnounce${NC}"
    echo -e "    Sub SSL:       $([ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && echo "${GREEN}✓ $SUB_CERT${NC}" || echo "${YELLOW}✗ Not configured${NC}")"
    echo -e "    Sub Protocol:  ${GREEN}$SUB_PROTOCOL${NC}"
    echo -e ""
    echo -e "  ${BLUE}Credentials:${NC}"
    echo -e "    Username:      ${GREEN}$PANEL_USER${NC}"
    echo -e "    Password:      ${YELLOW}[stored as hash in DB]${NC}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Ask user to confirm or edit
    echo -e "\n${YELLOW}[?] Subscription URL will be: ${GREEN}$SUB_BASE/$SUB_PATH/{user.subId}${NC}"
    read -p "$(echo -e ${YELLOW}'[?] Is this correct? (Y/n/edit): '${NC})" confirm
    confirm=${confirm:-Y}
    
    if [[ "$confirm" =~ ^[Nn] ]]; then
        read -p "  Sub Port [$SUB_PORT]: " input
        [ -n "$input" ] && SUB_PORT="$input"
        
        read -p "  Sub Path [$SUB_PATH]: " input
        [ -n "$input" ] && SUB_PATH="$input"
        
        read -p "  Sub Domain [$SUB_DOMAIN]: " input
        [ -n "$input" ] && SUB_DOMAIN="$input"
        
        read -p "  Panel Username [$PANEL_USER]: " input
        [ -n "$input" ] && PANEL_USER="$input"
        
        read -s -p "  Panel Password: " input
        echo
        [ -n "$input" ] && PANEL_PASS="$input"
    elif [[ "$confirm" =~ ^[Ee] ]]; then
        echo -e "\n${BLUE}Edit settings:${NC}"
        read -p "  Sub Port [$SUB_PORT]: " input
        [ -n "$input" ] && SUB_PORT="$input"
        
        read -p "  Sub Path [$SUB_PATH]: " input
        [ -n "$input" ] && SUB_PATH="$input"
        
        read -p "  Sub Domain [$SUB_DOMAIN]: " input
        [ -n "$input" ] && SUB_DOMAIN="$input"
        
        read -p "  Panel Username [$PANEL_USER]: " input
        [ -n "$input" ] && PANEL_USER="$input"
        
        read -s -p "  Panel Password (leave empty to skip): " input
        echo
        [ -n "$input" ] && PANEL_PASS="$input"
    else
        if [ -z "$PANEL_PASS" ]; then
            echo -e "\n${YELLOW}⚠ Password is required to authenticate with 3x-ui API${NC}"
            read -s -p "  Enter panel password for '$PANEL_USER': " PANEL_PASS
            echo
        fi
    fi
    
    if [ -z "$PANEL_PASS" ]; then
        echo -e "${YELLOW}⚠ Warning: No password provided. You will need to edit pgclock.config manually.${NC}"
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
    
    # Build the SUBSCRIPTION URL exactly as 3x-ui builds it
    local sub_url="$SUB_BASE/${SUB_PATH}/"
    
    echo -e "  ${BLUE}→ Generating pgclock.config with all settings...${NC}"
    cat > "$CONFIG_FILE" << EOF
# ==========================================
# Auto-generated by PGClock Smart Installer
# Source: github.com/9800/PGClock-Fusion_xui
# ==========================================

# Panel connection settings (for API authentication)
PROTOCOL=$SUB_PROTOCOL
HOST=$SUB_DOMAIN
PORT=$WEB_PORT
PATH=$WEB_BASE_PATH
USERNAME=$PANEL_USER
PASSWORD=$PANEL_PASS

# Subscription URL (matches what 3x-ui uses)
SUBSCRIPTION=$sub_url

# SSL certificates for the template server (same as 3x-ui subscription)
$([ -n "$SUB_CERT" ] && [ -f "$SUB_CERT" ] && echo "PUBLIC_KEY_PATH=$SUB_CERT" || echo "#PUBLIC_KEY_PATH=")
$([ -n "$SUB_KEY" ] && [ -f "$SUB_KEY" ] && echo "PRIVATE_KEY_PATH=$SUB_KEY" || echo "#PRIVATE_KEY_PATH=")

# Backup link (optional)
Backup_link=

# Template server ports (same as 3x-ui subscription port!)
SUB_HTTP_PORT=$SUB_PORT
$([ "$SUB_PROTOCOL" = "https" ] && echo "SUB_HTTPS_PORT=$SUB_PORT" || echo "#SUB_HTTPS_PORT=")

TEMPLATE_NAME=default

# Branding from 3x-ui panel settings
BRAND_NAME=${SUB_TITLE:-PGClock Fusion X-UI}
BRAND_LOGO=

# Support and metadata URLs from 3x-ui panel
TELEGRAM_URL=${SUB_SUPPORT_URL:-}
WHATSAPP_URL=
SUPPORT_URL=${SUB_SUPPORT_URL:-}
PROFILE_URL=${SUB_PROFILE_URL:-}
ANNOUNCE=${SUB_ANNOUNCE:-}

# 2FA settings
TWO_FACTOR=false
TOTP_SECRET=
EOF

    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓ Project files installed with all settings${NC}"
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

# ========== STEP 6: Verify & Show Instructions ==========
configure_panel() {
    echo -e "\n${YELLOW}[6/6] Verifying installation...${NC}"
    
    local sub_url="$SUB_BASE/${SUB_PATH}/{user.subId}"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✓ Installation completed successfully!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}📋 Service Status:${NC}"
    systemctl status PGCLOCK_XUI --no-pager -l | head -5
    
    echo -e "\n${BLUE}🔗 Template Subscription URL:${NC}"
    echo -e "  ${GREEN}$sub_url${NC}"
    
    echo -e "\n${BLUE}📊 Configuration Source:${NC}"
    echo -e "  All settings were read ${GREEN}directly from 3x-ui database${NC}"
    echo -e "  Database: ${BLUE}$XUI_DB${NC}"
    echo -e ""
    echo -e "  ${BLUE}Subscription Settings from DB:${NC}"
    echo -e "    ${GREEN}subPort${NC}:         $SUB_PORT"
    echo -e "    ${GREEN}subPath${NC}:         $SUB_PATH"
    echo -e "    ${GREEN}subURI${NC}:          ${SUB_URI:-$SUB_PATH}"
    echo -e "    ${GREEN}subTitle${NC}:        ${SUB_TITLE:-Not set}"
    echo -e "    ${GREEN}subDomain${NC}:       $SUB_DOMAIN"
    echo -e "    ${GREEN}subSupportUrl${NC}:  ${SUB_SUPPORT_URL:-Not set}"
    echo -e "    ${GREEN}subProfileUrl${NC}:  ${SUB_PROFILE_URL:-Not set}"
    echo -e "    ${GREEN}subAnnounce${NC}:    ${SUB_ANNOUNCE:-Not set}"
    
    echo -e "\n${BLUE}📱 Template server is now listening on:${NC}"
    echo -e "  ${GREEN}$SUB_PROTOCOL://$SUB_DOMAIN:$SUB_PORT${NC}"
    echo -e "  (Same port as 3x-ui subscription server!)"
    
    echo -e "\n${BLUE}🛠  Management Commands:${NC}"
    echo -e "  ${YELLOW}systemctl status PGCLOCK_XUI${NC}   - Check status"
    echo -e "  ${YELLOW}systemctl restart PGCLOCK_XUI${NC}  - Restart service"
    echo -e "  ${YELLOW}journalctl -u PGCLOCK_XUI -f${NC}   - View logs"
    echo -e "  ${YELLOW}nano $CONFIG_FILE${NC}  - Edit config"
    
    echo -e "\n${YELLOW}⚠️  Important Notes:${NC}"
    echo -e "  • Make sure port ${GREEN}$SUB_PORT${NC} is open in your firewall"
    echo -e "  • The template server runs on the ${GREEN}same port${NC} as 3x-ui's subscription server"
    echo -e "  • All metadata (title, support URL, announce) imported from 3x-ui panel"
    echo -e "  • If 3x-ui subscription is disabled, the template will handle all requests"
    echo -e "  • You may need to ${YELLOW}disable 3x-ui's built-in subscription server${NC} to avoid conflicts"
    
    if command -v ufw &> /dev/null; then
        read -p "$(echo -e ${YELLOW}'[?] Open port $SUB_PORT in UFW firewall? (Y/n): '${NC})" open_fw
        if [[ ! "$open_fw" =~ ^[Nn] ]]; then
            ufw allow "$SUB_PORT/tcp" > /dev/null 2>&1
            echo -e "${GREEN}✓ Firewall port opened${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}🎯 Next Steps:${NC}"
    echo -e "  1. Verify template server is running: ${YELLOW}curl -s http://$SUB_DOMAIN:$SUB_PORT${NC}"
    echo -e "  2. Test with a user's subId: ${YELLOW}$sub_url${NC}"
    echo -e "  3. Check that branding (title, support URL) appears correctly"
    echo -e "  4. If 3x-ui's sub server conflicts, disable it in panel settings"
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

# ========== Update ==========
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
    echo -e "  ${GREEN}1.${NC} Install PGClock Fusion (Auto-detect from 3x-ui DB)"
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
