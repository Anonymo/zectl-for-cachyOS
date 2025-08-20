#!/bin/bash

# Simplified zectl Installation Script for CachyOS with ZFS Root
# This version avoids custom PKGBUILDs and focuses on reliable AUR installation with zfs-dkms prevention

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

# Check if ZFS is available
if ! command -v zfs &> /dev/null; then
    error "ZFS is not installed or not in PATH"
fi

log "Starting simplified zectl installation on CachyOS with ZFS root..."

# Prevent zfs-dkms installation
log "Configuring pacman to prevent zfs-dkms installation..."
if ! grep -q "IgnorePkg.*zfs-dkms" /etc/pacman.conf; then
    # Backup original pacman.conf
    if [[ ! -f /etc/pacman.conf.backup-zectl ]]; then
        cp /etc/pacman.conf /etc/pacman.conf.backup-zectl
        log "Backed up original pacman.conf"
    fi
    
    # Add IgnorePkg line
    if grep -q "^IgnorePkg" /etc/pacman.conf; then
        sed -i 's/^IgnorePkg.*$/& zfs-dkms spl-dkms/' /etc/pacman.conf
    else
        sed -i '/^\[options\]/a IgnorePkg = zfs-dkms spl-dkms' /etc/pacman.conf
    fi
    
    success "Added zfs-dkms and spl-dkms to IgnorePkg"
fi

# Update system
log "Updating system packages..."
pacman -Syu --noconfirm || warning "System update failed, continuing anyway..."

# Install build dependencies
log "Installing build dependencies..."
pacman -S --needed --noconfirm base-devel git || error "Failed to install build dependencies"

# Install yay if not present
if ! command -v yay &> /dev/null; then
    log "Installing yay AUR helper..."
    
    # Find a regular user
    build_user=$(getent passwd | grep -E '/home/[^:]+' | grep -v 'nobody' | head -1 | cut -d: -f1)
    if [[ -z "$build_user" ]]; then
        error "No regular user found. Please install yay manually as a regular user first."
    fi
    
    log "Installing yay as user: $build_user"
    
    # Build yay
    sudo -u "$build_user" bash << 'EOF'
cd /tmp
rm -rf yay-git
git clone https://aur.archlinux.org/yay-git.git
cd yay-git
makepkg -si --noconfirm
EOF

    if ! command -v yay &> /dev/null; then
        error "Failed to install yay"
    fi
    
    success "Installed yay AUR helper"
else
    log "yay is already installed"
fi

# Install zectl-git with explicit ignore
log "Installing zectl-git from AUR (with zfs-dkms ignore)..."
build_user=$(getent passwd | grep -E '/home/[^:]+' | grep -v 'nobody' | head -1 | cut -d: -f1)

sudo -u "$build_user" yay -S --noconfirm --ignore zfs-dkms,spl-dkms zectl-git || {
    warning "yay failed, trying manual build..."
    sudo -u "$build_user" bash << 'EOF'
cd /tmp
rm -rf zectl-git
git clone https://aur.archlinux.org/zectl-git.git
cd zectl-git
makepkg -si --noconfirm --ignore zfs-dkms,spl-dkms
EOF
}

# Install zectl-pacman-hook
log "Installing zectl-pacman-hook..."
sudo -u "$build_user" yay -S --noconfirm --ignore zfs-dkms,spl-dkms zectl-pacman-hook || warning "Failed to install zectl-pacman-hook"

# Auto-detect system configuration (simplified)
log "Detecting system configuration..."

# Detect ZFS pool
ZFS_POOL=$(zpool list -H -o name 2>/dev/null | head -1)
if [[ -z "$ZFS_POOL" ]]; then
    error "Could not detect ZFS pool"
fi
log "Detected ZFS pool: $ZFS_POOL"

# Detect bootloader
BOOTLOADER="systemd-boot"
ESP_PATH="/boot"

if [[ -f /boot/efi/EFI/systemd/systemd-bootx64.efi ]]; then
    ESP_PATH="/boot/efi"
elif [[ -f /efi/EFI/systemd/systemd-bootx64.efi ]]; then
    ESP_PATH="/efi"
fi

log "Using bootloader: $BOOTLOADER"
log "Using ESP path: $ESP_PATH"

# Create zectl configuration
log "Creating zectl configuration..."
mkdir -p /etc/zectl

cat > /etc/zectl/zectl.conf << EOF
[zectl]
pool = $ZFS_POOL
boot_environment_root = ROOT
kernel_prefix = vmlinuz-
initramfs_prefix = initramfs-
unified_kernel_images = false

[bootloader]
bootloader = $BOOTLOADER
kernel_options = 
EOF

# Configure systemd-boot
if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    log "Configuring systemd-boot..."
    
    # Backup existing loader.conf
    if [[ -f "$ESP_PATH/loader/loader.conf" ]]; then
        cp "$ESP_PATH/loader/loader.conf" "$ESP_PATH/loader/loader.conf.backup-$(date +%Y%m%d)"
    fi
    
    # Create entries directory
    mkdir -p "$ESP_PATH/loader/entries"
    
    # Update loader.conf with longer timeout
    cat > "$ESP_PATH/loader/loader.conf" << EOF
default @saved
timeout 10
console-mode max
editor no
auto-entries yes
auto-firmware yes
EOF
    
    success "Configured systemd-boot"
fi

# Create initial boot environment
log "Creating initial boot environment..."
BE_NAME="initial-$(date +%Y%m%d)"
if ! zectl list | grep -q "$BE_NAME"; then
    zectl create "$BE_NAME" || warning "Failed to create initial boot environment"
    
    # Generate boot entries
    zectl generate-bootloader-entries || warning "Failed to generate boot entries"
    
    # Update bootctl
    if command -v bootctl &>/dev/null; then
        bootctl update || warning "Failed to update systemd-boot"
    fi
else
    log "Boot environment $BE_NAME already exists"
fi

# Create simple utility script
log "Creating utility script..."
cat > /usr/local/bin/zectl-manager << 'EOF'
#!/bin/bash
case "$1" in
    "list") zectl list ;;
    "create") zectl create "${2:-snapshot-$(date +%Y%m%d-%H%M%S)}" ;;
    "activate") zectl activate "$2" ;;
    "destroy") zectl destroy "$2" ;;
    "snapshot") zectl create "snapshot-$(date +%Y%m%d-%H%M%S)" ;;
    *) echo "Usage: zectl-manager {list|create|activate|destroy|snapshot} [name]" ;;
esac
EOF

chmod +x /usr/local/bin/zectl-manager

# Test installation
log "Testing zectl installation..."
if zectl list &> /dev/null; then
    success "zectl is working correctly!"
    echo ""
    zectl list
else
    warning "zectl may not be properly configured"
fi

echo ""
echo "==============================================="
success "Simplified zectl installation completed!"
echo "==============================================="
echo ""
echo "Usage:"
echo "  zectl list                    - List boot environments"
echo "  zectl create my-backup        - Create boot environment"
echo "  zectl activate my-backup      - Activate boot environment"
echo "  zectl-manager snapshot        - Quick snapshot"
echo ""
echo "Note: Reboot to see boot environments in systemd-boot menu"
echo "Note: zfs-dkms has been added to IgnorePkg in pacman.conf"
EOF