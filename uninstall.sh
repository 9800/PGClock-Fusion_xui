#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TEMPLATE_DIR="/etc/3x-ui/sub_templates/pgclock"

[[ $EUID -ne 0 ]] && echo -e "${RED}✗ Please run with root${NC}" && exit 1

echo -e "${YELLOW}Uninstalling PGClock Fusion template...${NC}"

if [ -d "$TEMPLATE_DIR" ]; then
    rm -rf "$TEMPLATE_DIR"
    echo -e "${GREEN}✓ Template files removed${NC}"
else
    echo -e "${YELLOW}! Template directory not found (already removed)${NC}"
fi

systemctl restart x-ui 2>/dev/null || x-ui restart 2>/dev/null
echo -e "${GREEN}✓ 3x-ui restarted${NC}"

echo -e ""
echo -e "${YELLOW}⚠ Important:${NC}"
echo -e "  Go to 3x-ui panel → ${GREEN}Settings → Subscription${NC}"
echo -e "  Clear the ${GREEN}\"Sub Theme Directory\"${NC} field"
echo -e "  Click ${GREEN}Save${NC}"
echo -e ""
echo -e "${GREEN}✓ Uninstall complete!${NC}"
