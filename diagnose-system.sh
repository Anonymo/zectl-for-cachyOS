#!/bin/bash

# System Diagnostic Script for zectl-for-cachyOS
# Helps identify issues that might affect system functionality after installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== zectl-for-cachyOS System Diagnostic ===${NC}"
echo ""

# Check ZFS status
echo -e "${BLUE}[1/6] ZFS Pool Status:${NC}"
if command -v zpool &>/dev/null; then
    zpool status
    echo ""
    zfs list -t filesystem | head -10
else
    echo -e "${RED}ZFS not found${NC}"
fi
echo ""

# Check ZFS services
echo -e "${BLUE}[2/6] ZFS Services Status:${NC}"
for service in zfs-import-cache.service zfs-import-scan.service zfs-mount.service zfs.target; do
    if systemctl list-unit-files "$service" &>/dev/null; then
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
        echo -e "$service: ${GREEN}$status${NC} (${YELLOW}$enabled${NC})"
    fi
done
echo ""

# Check power management
echo -e "${BLUE}[3/6] Power Management:${NC}"
echo "Sleep states available:"
if [[ -f /sys/power/state ]]; then
    cat /sys/power/state
else
    echo -e "${RED}Cannot read /sys/power/state${NC}"
fi

echo ""
echo "Current power policy:"
if [[ -f /sys/power/policy ]]; then
    cat /sys/power/policy 2>/dev/null || echo "Not available"
else
    echo "Not available"
fi
echo ""

# Check recent system logs for sleep/wake issues
echo -e "${BLUE}[4/6] Recent Sleep/Wake Logs:${NC}"
echo "Checking for suspend/resume issues in last boot..."
if journalctl -b 0 --no-pager -q | grep -i -E "(suspend|resume|sleep|wake|hibernate)" | tail -10; then
    echo ""
else
    echo "No sleep/wake related messages found"
fi
echo ""

# Check systemd sleep configuration
echo -e "${BLUE}[5/6] systemd Sleep Configuration:${NC}"
if [[ -f /etc/systemd/sleep.conf ]]; then
    echo "Custom sleep configuration found:"
    grep -v '^#' /etc/systemd/sleep.conf | grep -v '^$' || echo "No custom settings"
else
    echo "Using default sleep configuration"
fi
echo ""

# Check for common problematic modules
echo -e "${BLUE}[6/6] Potentially Problematic Modules:${NC}"
echo "Loaded modules that might affect sleep:"
lsmod | grep -E "(nvidia|nouveau|amdgpu|radeon)" || echo "No problematic GPU modules found"
echo ""

# Recommendations
echo -e "${YELLOW}=== Recommendations ===${NC}"
echo ""

if systemctl is-active zfs-import-cache.service &>/dev/null; then
    echo -e "${YELLOW}⚠️  ZFS import services are running.${NC}"
    echo "If experiencing sleep issues, try:"
    echo "  sudo systemctl disable zfs-import-cache.service"
    echo "  sudo systemctl mask zfs-import-cache.service"
    echo ""
fi

echo -e "${BLUE}To test sleep manually:${NC}"
echo "  sudo systemctl suspend"
echo ""

echo -e "${BLUE}To check what's preventing sleep:${NC}"
echo "  cat /sys/power/wakeup_count"
echo "  cat /proc/acpi/wakeup"
echo ""

echo -e "${BLUE}To check systemd sleep inhibitors:${NC}"
echo "  systemd-inhibit --list"
echo ""

echo -e "${GREEN}Diagnostic complete.${NC}"
echo "If you're still having issues, please share this output when asking for help."