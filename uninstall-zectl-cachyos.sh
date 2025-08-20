#!/bin/bash

# Uninstall Script for zectl-for-cachyOS
# Removes all components installed by install-zectl-cachyos.sh and setup-secureboot-cachyos.sh
# Restores system to pre-installation state

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

echo -e "${BLUE}=== zectl-for-cachyOS Uninstaller ===${NC}"
echo ""
echo "This will remove all components installed by zectl-for-cachyOS:"
echo "- zectl packages (zectl-cachyos, zectl-git, zectl-pacman-hook)"
echo "- Secure Boot components (sbctl, keys, hooks)"
echo "- Configuration files and utility scripts"
echo "- pacman.conf modifications (restore IgnorePkg)"
echo ""
read -p "Continue with uninstallation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

log "Starting zectl-for-cachyOS uninstallation..."

# Remove zectl packages
log "Removing zectl packages..."
packages_to_remove=()

# Check for our custom packages
if pacman -Q zectl-cachyos &>/dev/null; then
    packages_to_remove+=("zectl-cachyos")
fi

if pacman -Q zectl-pacman-hook-cachyos &>/dev/null; then
    packages_to_remove+=("zectl-pacman-hook-cachyos")
fi

# Check for AUR packages
if pacman -Q zectl-git &>/dev/null; then
    packages_to_remove+=("zectl-git")
fi

if pacman -Q zectl &>/dev/null; then
    packages_to_remove+=("zectl")
fi

if pacman -Q zectl-pacman-hook &>/dev/null; then
    packages_to_remove+=("zectl-pacman-hook")
fi

if [[ ${#packages_to_remove[@]} -gt 0 ]]; then
    log "Removing packages: ${packages_to_remove[*]}"
    pacman -R --noconfirm "${packages_to_remove[@]}" || warning "Some packages failed to remove"
    success "Removed zectl packages"
else
    log "No zectl packages found to remove"
fi

# Remove Secure Boot packages (optional)
log "Checking for Secure Boot components..."
secureboot_packages=()

if pacman -Q sbctl &>/dev/null; then
    secureboot_packages+=("sbctl")
fi

if pacman -Q sbsigntools &>/dev/null; then
    secureboot_packages+=("sbsigntools")
fi

if [[ ${#secureboot_packages[@]} -gt 0 ]]; then
    echo ""
    echo "Found Secure Boot packages: ${secureboot_packages[*]}"
    read -p "Remove Secure Boot packages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pacman -R --noconfirm "${secureboot_packages[@]}" || warning "Some Secure Boot packages failed to remove"
        success "Removed Secure Boot packages"
    else
        log "Keeping Secure Boot packages"
    fi
fi

# Remove configuration files
log "Removing configuration files..."

# Remove zectl configuration
if [[ -d /etc/zectl ]]; then
    rm -rf /etc/zectl
    success "Removed /etc/zectl directory"
fi

# Remove pacman hooks
hooks_removed=0
for hook in /etc/pacman.d/hooks/95-zectl-kernel.hook /etc/pacman.d/hooks/99-secureboot-kernel-sign.hook; do
    if [[ -f "$hook" ]]; then
        rm -f "$hook"
        success "Removed $hook"
        ((hooks_removed++))
    fi
done

if [[ $hooks_removed -eq 0 ]]; then
    log "No pacman hooks found to remove"
fi

# Remove utility scripts
log "Removing utility scripts..."
scripts_removed=0

for script in /usr/local/bin/zectl-manager /usr/local/bin/secureboot-manager; do
    if [[ -f "$script" ]]; then
        rm -f "$script"
        success "Removed $script"
        ((scripts_removed++))
    fi
done

if [[ $scripts_removed -eq 0 ]]; then
    log "No utility scripts found to remove"
fi

# Restore pacman.conf
log "Restoring pacman.conf..."

# Check if backup exists
if [[ -f /etc/pacman.conf.backup-zectl ]]; then
    log "Found pacman.conf backup, restoring..."
    cp /etc/pacman.conf.backup-zectl /etc/pacman.conf
    success "Restored original pacman.conf from backup"
    
    # Remove backup file
    rm -f /etc/pacman.conf.backup-zectl
    log "Removed backup file"
else
    # Manual removal of IgnorePkg entries
    log "No backup found, manually removing IgnorePkg entries..."
    
    # Remove our IgnorePkg entries
    sed -i '/IgnorePkg.*zfs-dkms/d' /etc/pacman.conf
    sed -i '/IgnorePkg.*spl-dkms/d' /etc/pacman.conf
    
    # If IgnorePkg line is empty now, remove it
    sed -i '/^IgnorePkg\s*=\s*$/d' /etc/pacman.conf
    
    success "Removed zfs-dkms and spl-dkms from IgnorePkg"
fi

# Remove Secure Boot keys and configuration (optional)
if [[ -d /usr/share/secureboot ]] || [[ -d /root/secureboot-backup ]]; then
    echo ""
    echo "Found Secure Boot keys and configuration"
    read -p "Remove Secure Boot keys and configuration? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -d /usr/share/secureboot ]]; then
            rm -rf /usr/share/secureboot
            success "Removed Secure Boot keys"
        fi
        
        if [[ -d /root/secureboot-backup ]]; then
            rm -rf /root/secureboot-backup
            success "Removed Secure Boot backup"
        fi
        
        warning "You may need to disable Secure Boot in UEFI settings"
        warning "Or enroll your distribution's keys if you want to keep Secure Boot"
    else
        log "Keeping Secure Boot keys and configuration"
    fi
fi

# Disable ZFS services that were enabled
log "Checking ZFS services..."
zfs_services=("zfs-mount.service" "zfs.target" "zfs-import-cache.service")
services_disabled=0

for service in "${zfs_services[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        read -p "Disable $service? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl disable "$service" || warning "Failed to disable $service"
            success "Disabled $service"
            ((services_disabled++))
        fi
    fi
done

if [[ $services_disabled -eq 0 ]]; then
    log "No ZFS services were disabled"
fi

# Check for systemd-boot configuration changes
log "Checking systemd-boot configuration..."
if [[ -f /boot/loader/loader.conf.backup-* ]] || [[ -f /efi/loader/loader.conf.backup-* ]]; then
    echo ""
    echo "Found systemd-boot configuration backup"
    read -p "Restore original systemd-boot configuration? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Find ESP path
        ESP_PATH=""
        for path in /boot /boot/efi /efi; do
            if mountpoint -q "$path" 2>/dev/null && [[ -f "$path/loader/loader.conf.backup-"* ]]; then
                ESP_PATH="$path"
                break
            fi
        done
        
        if [[ -n "$ESP_PATH" ]]; then
            backup_file=$(ls "$ESP_PATH/loader/loader.conf.backup-"* | head -1)
            if [[ -f "$backup_file" ]]; then
                cp "$backup_file" "$ESP_PATH/loader/loader.conf"
                success "Restored original systemd-boot configuration"
                rm -f "$ESP_PATH/loader/loader.conf.backup-"*
                log "Removed backup files"
            fi
        fi
    fi
fi

# Clean up temporary build directories
log "Cleaning up temporary files..."
rm -rf /tmp/zectl-*-build 2>/dev/null || true
rm -rf /tmp/yay 2>/dev/null || true

# Final system status
echo ""
echo -e "${BLUE}=== Uninstallation Summary ===${NC}"
echo ""

# Check remaining components
remaining_issues=()

if command -v zectl &>/dev/null; then
    remaining_issues+=("zectl command still available")
fi

if [[ -d /etc/zectl ]]; then
    remaining_issues+=("/etc/zectl directory still exists")
fi

if grep -q "zfs-dkms" /etc/pacman.conf 2>/dev/null; then
    remaining_issues+=("zfs-dkms still in pacman.conf IgnorePkg")
fi

if [[ ${#remaining_issues[@]} -gt 0 ]]; then
    warning "Some components may still be present:"
    for issue in "${remaining_issues[@]}"; do
        echo "  - $issue"
    done
    echo ""
    echo "You may need to manually remove these components."
else
    success "All zectl-for-cachyOS components have been removed"
fi

echo ""
echo -e "${GREEN}Uninstallation completed!${NC}"
echo ""
echo "Notes:"
echo "- You can now install regular zectl from AUR if desired"
echo "- ZFS functionality is still available (built into CachyOS kernel)"
echo "- Boot environments created by zectl still exist in your ZFS pool"
echo "- Run 'zfs list -t snapshot' to see any remaining snapshots"
echo ""
echo "To completely remove ZFS boot environments and snapshots:"
echo "  zfs destroy -r pool/ROOT/environment-name"
echo "  (Replace 'pool' and 'environment-name' with actual values)"