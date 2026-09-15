#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
TEMPLATE_DIR="/etc/3x-ui/sub_templates/pgclock"
REPO_RAW="https://raw.githubusercontent.com/9800/PGClock-Fusion_xui/main"

[[ $EUID -ne 0 ]] && echo -e "${RED}✗ Please run with root${NC}" && exit 1

clear
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"
echo -e "${BLUE}|   PGClock Fusion - Custom Subscription Template for 3x-ui         |${NC}"
echo -e "${BLUE}+--------------------------------------------------------------------+${NC}"

# Check if 3x-ui is installed
XUI_DIR=""
for dir in "/etc/3x-ui" "/usr/local/x-ui" "/opt/x-ui"; do
    if [ -d "$dir" ]; then
        XUI_DIR="$dir"
        break
    fi
done

if [ -z "$XUI_DIR" ]; then
    echo -e "${RED}✗ 3x-ui not found!${NC}"
    echo -e "Install 3x-ui first:"
    echo -e "${BLUE}bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)${NC}"
    exit 1
fi

echo -e "\n${GREEN}✓ Found 3x-ui at: $XUI_DIR${NC}"

# Step 1: Create template directory
echo -e "\n${YELLOW}[1/3] Creating template directory...${NC}"
mkdir -p "$TEMPLATE_DIR"
echo -e "${GREEN}✓ Directory created: $TEMPLATE_DIR${NC}"

# Step 2: Download PGClock template
echo -e "\n${YELLOW}[2/3] Downloading PGClock template...${NC}"
wget -q "$REPO_RAW/template/index.html" -O "$TEMPLATE_DIR/index.html"
chmod 644 "$TEMPLATE_DIR/index.html"
echo -e "${GREEN}✓ Template downloaded${NC}"

# Step 3: Restart 3x-ui
echo -e "\n${YELLOW}[3/3] Restarting 3x-ui...${NC}"
systemctl restart x-ui 2>/dev/null || x-ui restart 2>/dev/null
sleep 2
echo -e "${GREEN}✓ 3x-ui restarted${NC}"

# Show results
echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✓ Template installed successfully!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}📁 Template location:${NC}"
echo -e "  ${GREEN}$TEMPLATE_DIR/index.html${NC}"

echo -e "\n${BLUE}⚙️  Final Step - Configure in 3x-ui Panel:${NC}"
echo -e "  ${YELLOW}1.${NC} Open your 3x-ui panel in browser"
echo -e "  ${YELLOW}2.${NC} Go to ${GREEN}Panel Settings${NC} → ${GREEN}Subscription Settings${NC}"
echo -e "  ${YELLOW}3.${NC} Find field: ${GREEN}\"Sub Theme Directory\"${NC}"
echo -e "  ${YELLOW}4.${NC} Paste this path:"
echo -e ""
echo -e "     ${GREEN}$TEMPLATE_DIR${NC}"
echo -e ""
echo -e "  ${YELLOW}5.${NC} Click ${GREEN}Save${NC}"
echo -e "  ${YELLOW}6.${NC} Test a user's subscription link - you'll see the new PGClock design!"

echo -e "\n${BLUE}🎯 What you get:${NC}"
echo -e "  ${GREEN}✓${NC} Beautiful PGClock Fusion design (Glassmorphism)"
echo -e "  ${GREEN}✓${NC} Live clock (Jalali + Gregorian)"
echo -e "  ${GREEN}✓${NC} Usage rings with color coding"
echo -e "  ${GREEN}✓${NC} Server list with country flags"
echo -e "  ${GREEN}✓${NC} Copy + QR code for each config"
echo -e "  ${GREEN}✓${NC} Apps section by OS"
echo -e "  ${GREEN}✓${NC} Dark/Light theme toggle"
echo -e "  ${GREEN}✓${NC} FA/EN language switch"

echo -e "\n${BLUE}📱 Subscription URL (unchanged!):${NC}"
echo -e "  ${GREEN}http(s)://your-domain:port/sub/{user.subId}${NC}"

echo -e "\n${BLUE}🛠  Management:${NC}"
echo -e "  ${YELLOW}nano $TEMPLATE_DIR/index.html${NC}  - Edit template"
echo -e "  ${YELLOW}systemctl restart x-ui${NC}          - Apply changes"
echo -e "  ${YELLOW}bash <(curl -Ls $REPO_RAW/uninstall.sh)${NC}  - Uninstall"

echo -e "\n${GREEN}✓ Installation complete!${NC}"
