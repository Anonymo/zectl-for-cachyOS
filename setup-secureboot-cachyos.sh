#!/bin/bash

# Secure Boot Setup Script for CachyOS with ZFS Root
# This script helps configure Secure Boot with signed kernels
# Run after installing zectl to ensure boot environments work with Secure Boot

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

log "Starting Secure Boot configuration for CachyOS with ZFS..."

# Check for UEFI mode
if [[ ! -d /sys/firmware/efi ]]; then
    error "System is not booted in UEFI mode. Secure Boot requires UEFI."
fi

# Check current Secure Boot status
check_secureboot_status() {
    if command -v mokutil &>/dev/null; then
        local status=$(mokutil --sb-state 2>/dev/null | grep "SecureBoot" | awk '{print $2}')
        echo "$status"
    elif [[ -f /sys/firmware/efi/efivars/SecureBoot-* ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

CURRENT_SB_STATUS=$(check_secureboot_status)
log "Current Secure Boot status: $CURRENT_SB_STATUS"

# Install required packages
log "Installing Secure Boot utilities..."
pacman -S --needed --noconfirm \
    sbctl \
    sbsigntools \
    efibootmgr \
    mokutil \
    tpm2-tools \
    tpm2-tss || warning "Some packages failed to install"

# Check if sbctl is available
if ! command -v sbctl &>/dev/null; then
    error "sbctl is not installed. Cannot continue."
fi

# Initialize sbctl if needed
if ! sbctl status &>/dev/null; then
    log "Initializing sbctl..."
    sbctl create-keys
fi

# Display current status
log "Checking sbctl status..."
sbctl status

# Find ESP path
ESP_PATH=""
for path in /boot /boot/efi /efi; do
    if mountpoint -q "$path" 2>/dev/null; then
        if df -T "$path" | grep -qE 'vfat|fat32'; then
            ESP_PATH="$path"
            break
        fi
    fi
done

if [[ -z "$ESP_PATH" ]]; then
    error "Could not find EFI System Partition"
fi
log "Found ESP at: $ESP_PATH"

# Detect bootloader
BOOTLOADER=""
if [[ -f "$ESP_PATH/EFI/systemd/systemd-bootx64.efi" ]]; then
    BOOTLOADER="systemd-boot"
elif [[ -f "$ESP_PATH/EFI/BOOT/grubx64.efi" ]] || [[ -f "$ESP_PATH/EFI/cachyos/grubx64.efi" ]]; then
    BOOTLOADER="grub"
elif [[ -f "$ESP_PATH/EFI/refind/refind_x64.efi" ]]; then
    BOOTLOADER="refind"
fi

if [[ -z "$BOOTLOADER" ]]; then
    warning "Could not detect bootloader"
    BOOTLOADER="systemd-boot"
fi
log "Detected bootloader: $BOOTLOADER"

# Function to sign a file
sign_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log "Signing $file..."
        sbctl sign -s "$file" || warning "Failed to sign $file"
    else
        warning "File not found: $file"
    fi
}

# Sign bootloader
case "$BOOTLOADER" in
    "systemd-boot")
        sign_file "$ESP_PATH/EFI/systemd/systemd-bootx64.efi"
        sign_file "$ESP_PATH/EFI/BOOT/BOOTX64.EFI"
        ;;
    "grub")
        sign_file "$ESP_PATH/EFI/BOOT/grubx64.efi"
        sign_file "$ESP_PATH/EFI/cachyos/grubx64.efi"
        ;;
    "refind")
        sign_file "$ESP_PATH/EFI/refind/refind_x64.efi"
        ;;
esac

# Sign kernels
log "Signing kernel images..."
for kernel in "$ESP_PATH"/vmlinuz-*; do
    if [[ -f "$kernel" ]]; then
        sign_file "$kernel"
    fi
done

# Sign unified kernel images if present
for uki in "$ESP_PATH"/EFI/Linux/*.efi; do
    if [[ -f "$uki" ]]; then
        sign_file "$uki"
    fi
done

# Create pacman hook for automatic kernel signing
log "Creating pacman hook for automatic kernel signing..."
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/99-secureboot-kernel-sign.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux*
Target = *-kernel

[Action]
Description = Signing kernel for Secure Boot...
When = PostTransaction
Exec = /usr/bin/sbctl sign-all
Depends = sbctl
EOF

# Configure sbctl for automatic signing
log "Configuring automatic signing..."
sbctl sign-all

# Create helper script for Secure Boot management
log "Creating Secure Boot management script..."
cat > /usr/local/bin/secureboot-manager << 'EOF'
#!/bin/bash

# Secure Boot Manager for CachyOS

case "$1" in
    "status")
        echo "Secure Boot Status:"
        sbctl status
        echo ""
        mokutil --sb-state 2>/dev/null || echo "mokutil not available"
        ;;
    "sign-all")
        echo "Signing all boot files..."
        sbctl sign-all
        ;;
    "verify")
        echo "Verifying signatures..."
        sbctl verify
        ;;
    "enroll")
        echo "Enrolling keys to firmware..."
        echo "WARNING: This will enable Secure Boot enforcement!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sbctl enroll-keys
            echo "Keys enrolled. Reboot to activate Secure Boot."
        fi
        ;;
    "bundle")
        if [[ -z "$2" ]]; then
            echo "Usage: secureboot-manager bundle <kernel-name>"
            exit 1
        fi
        echo "Creating unified kernel image for $2..."
        sbctl bundle -s -k /boot/vmlinuz-$2 -f /boot/initramfs-$2.img /boot/EFI/Linux/$2.efi
        ;;
    "help"|*)
        echo "Secure Boot Manager"
        echo ""
        echo "Usage: secureboot-manager <command>"
        echo ""
        echo "Commands:"
        echo "  status       - Show Secure Boot status"
        echo "  sign-all     - Sign all boot files"
        echo "  verify       - Verify all signatures"
        echo "  enroll       - Enroll keys to firmware (enables enforcement)"
        echo "  bundle       - Create unified kernel image"
        echo "  help         - Show this help"
        ;;
esac
EOF

chmod +x /usr/local/bin/secureboot-manager

# Create backup of current keys
log "Creating backup of Secure Boot keys..."
mkdir -p /root/secureboot-backup
if [[ -d /usr/share/secureboot/keys ]]; then
    cp -r /usr/share/secureboot/keys /root/secureboot-backup/
    success "Keys backed up to /root/secureboot-backup/"
fi

# Check if keys need to be enrolled
if ! sbctl status | grep -q "Enrolled.*yes"; then
    warning "Secure Boot keys are not enrolled in firmware"
    echo ""
    echo "To complete Secure Boot setup:"
    echo "1. Review the signed files with: sbctl verify"
    echo "2. Enroll keys with: secureboot-manager enroll"
    echo "3. Reboot and enable Secure Boot in UEFI settings"
else
    success "Secure Boot keys are already enrolled"
fi

# Summary
echo ""
echo "==============================================="
success "Secure Boot configuration completed!"
echo "==============================================="
echo ""
echo "Current Status:"
sbctl status
echo ""
echo "Next steps:"
echo "1. Verify all files are signed: secureboot-manager verify"
if [[ "$CURRENT_SB_STATUS" != "enabled" ]]; then
    echo "2. Enroll keys if not done: secureboot-manager enroll"
    echo "3. Reboot and enable Secure Boot in UEFI firmware settings"
else
    echo "2. Secure Boot is already enabled"
fi
echo ""
echo "Kernels will be automatically signed after updates."
echo ""
echo "Use 'secureboot-manager help' for management commands."