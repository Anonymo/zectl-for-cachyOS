#!/bin/bash

# zectl Installation Script for CachyOS with ZFS Root
# Enhanced version with auto-detection for various system configurations
# Run this script after installing CachyOS with ZFS root option

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

debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1"
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Check if ZFS is available
if ! command -v zfs &> /dev/null; then
    error "ZFS is not installed or not in PATH"
fi

# Auto-detect system configuration
log "Detecting system configuration..."

# Detect ZFS root pool
detect_zfs_pool() {
    local pool=""
    
    # Method 1: Check mounted root
    if mountpoint -q / && df -T / | grep -q zfs; then
        pool=$(df -T / | grep zfs | awk '{print $1}' | cut -d'/' -f1)
        debug "Detected pool from mounted root: $pool"
    fi
    
    # Method 2: Check zpool list
    if [[ -z "$pool" ]]; then
        pool=$(zpool list -H -o name 2>/dev/null | head -1)
        debug "Detected pool from zpool list: $pool"
    fi
    
    # Method 3: Check for common pool names
    if [[ -z "$pool" ]]; then
        for common_pool in zroot rpool tank pool; do
            if zpool list "$common_pool" &>/dev/null; then
                pool="$common_pool"
                debug "Found common pool name: $pool"
                break
            fi
        done
    fi
    
    echo "$pool"
}

# Detect boot loader configuration
detect_bootloader() {
    local bootloader=""
    local esp_path=""
    
    # Check for systemd-boot
    if command -v bootctl &>/dev/null; then
        if bootctl status &>/dev/null; then
            bootloader="systemd-boot"
            # Try to find ESP path from bootctl
            esp_path=$(bootctl status 2>/dev/null | grep "ESP" | grep -oE '/[^ ]+' | head -1)
            debug "Detected systemd-boot with ESP at: $esp_path"
        fi
    fi
    
    # Check for GRUB
    if [[ -z "$bootloader" ]]; then
        if [[ -f /boot/grub/grub.cfg ]] || [[ -f /boot/grub2/grub.cfg ]]; then
            bootloader="grub"
            debug "Detected GRUB"
        fi
    fi
    
    # Check for rEFInd
    if [[ -z "$bootloader" ]]; then
        if [[ -d /boot/efi/EFI/refind ]] || [[ -d /efi/EFI/refind ]]; then
            bootloader="refind"
            debug "Detected rEFInd"
        fi
    fi
    
    # Find ESP path if not already found
    if [[ -z "$esp_path" ]]; then
        for path in /boot /boot/efi /efi; do
            if mountpoint -q "$path" 2>/dev/null; then
                if df -T "$path" | grep -qE 'vfat|fat32'; then
                    esp_path="$path"
                    debug "Found ESP at: $esp_path"
                    break
                fi
            fi
        done
    fi
    
    echo "$bootloader:$esp_path"
}

# Detect root dataset
detect_root_dataset() {
    local root_ds=""
    
    # Try to get from mount
    if mount | grep -E '^.* on / ' | grep -q zfs; then
        root_ds=$(mount | grep -E '^.* on / ' | awk '{print $1}')
        debug "Root dataset from mount: $root_ds"
    fi
    
    # Fallback to checking common patterns
    if [[ -z "$root_ds" ]]; then
        local pool="$1"
        for pattern in ROOT/cachyos ROOT/arch ROOT/default; do
            if zfs list "$pool/$pattern" &>/dev/null; then
                root_ds="$pool/$pattern"
                debug "Found root dataset: $root_ds"
                break
            fi
        done
    fi
    
    echo "$root_ds"
}

# Main detection
ZFS_POOL=$(detect_zfs_pool)
if [[ -z "$ZFS_POOL" ]]; then
    error "Could not detect ZFS pool. Please ensure system is running on ZFS root."
fi
log "Detected ZFS pool: $ZFS_POOL"

BOOTLOADER_INFO=$(detect_bootloader)
BOOTLOADER=$(echo "$BOOTLOADER_INFO" | cut -d':' -f1)
ESP_PATH=$(echo "$BOOTLOADER_INFO" | cut -d':' -f2)

if [[ -z "$BOOTLOADER" ]]; then
    warning "Could not detect bootloader. Defaulting to systemd-boot"
    BOOTLOADER="systemd-boot"
fi
log "Detected bootloader: $BOOTLOADER"

if [[ -n "$ESP_PATH" ]]; then
    log "Detected ESP path: $ESP_PATH"
else
    ESP_PATH="/boot"
    warning "Could not detect ESP path. Using default: $ESP_PATH"
fi

ROOT_DATASET=$(detect_root_dataset "$ZFS_POOL")
if [[ -n "$ROOT_DATASET" ]]; then
    log "Detected root dataset: $ROOT_DATASET"
fi

# Confirmation prompt
echo ""
echo "System Configuration Detected:"
echo "  ZFS Pool: $ZFS_POOL"
echo "  Bootloader: $BOOTLOADER"
echo "  ESP Path: $ESP_PATH"
[[ -n "$ROOT_DATASET" ]] && echo "  Root Dataset: $ROOT_DATASET"
echo ""
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

log "Starting zectl installation on CachyOS with ZFS root..."

# Update system first
log "Updating system packages..."
pacman -Syu --noconfirm || warning "System update failed, continuing anyway..."

# Install required dependencies
log "Installing build dependencies..."
pacman -S --needed --noconfirm base-devel git cmake make scdoc || {
    warning "Some packages failed to install, checking individually..."
    for pkg in base-devel git cmake make scdoc; do
        pacman -S --needed --noconfirm "$pkg" 2>/dev/null || warning "Failed to install $pkg"
    done
}

# Add to pacman.conf to ignore zfs-dkms (CachyOS has ZFS built-in)
log "Configuring pacman to ignore zfs-dkms (CachyOS has ZFS built-in)..."
if ! grep -q "IgnorePkg.*zfs-dkms" /etc/pacman.conf; then
    sed -i '/^#IgnorePkg/a IgnorePkg = zfs-dkms spl-dkms' /etc/pacman.conf
    log "Added zfs-dkms and spl-dkms to IgnorePkg in pacman.conf"
fi

# Function to install AUR package without password prompts
install_aur_package() {
    local package="$1"
    local build_user
    
    # Find a regular user to build with (avoid nobody which needs password setup)
    build_user=$(getent passwd | grep -E '/home/[^:]+' | head -1 | cut -d: -f1)
    
    if [[ -z "$build_user" ]]; then
        # Fallback: create temporary build user
        log "Creating temporary build user for AUR packages..."
        useradd -m -G wheel -s /bin/bash builduser 2>/dev/null || true
        echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builduser
        build_user="builduser"
    fi
    
    log "Installing $package from AUR as user $build_user..."
    
    # Install yay if not present
    if ! command -v yay &>/dev/null; then
        log "Installing yay AUR helper..."
        cd /tmp
        rm -rf yay
        git clone https://aur.archlinux.org/yay.git
        cd yay
        chown -R "$build_user:$build_user" .
        sudo -u "$build_user" makepkg -si --noconfirm
        cd /
    fi
    
    # Install the requested package
    if sudo -u "$build_user" yay -S --noconfirm "$package"; then
        success "Successfully installed $package"
    else
        warning "Failed to install $package via yay, trying manual build..."
        cd /tmp
        rm -rf "$package"
        git clone "https://aur.archlinux.org/$package.git"
        cd "$package"
        chown -R "$build_user:$build_user" .
        sudo -u "$build_user" makepkg -si --noconfirm || warning "Failed to build $package manually"
        cd /
    fi
    
    # Cleanup temporary user if created
    if [[ "$build_user" == "builduser" ]]; then
        userdel -r builduser 2>/dev/null || true
        rm -f /etc/sudoers.d/builduser
    fi
}

# Install zectl-git from AUR
install_aur_package "zectl-git"

# Install optional zectl-pacman-hook
log "Installing zectl-pacman-hook for automatic boot environment management..."
install_aur_package "zectl-pacman-hook"

# Create zectl configuration
log "Creating zectl configuration..."
mkdir -p /etc/zectl

# Determine boot environment root
BE_ROOT="ROOT"
if [[ -n "$ROOT_DATASET" ]]; then
    BE_ROOT=$(echo "$ROOT_DATASET" | cut -d'/' -f2)
fi

cat > /etc/zectl/zectl.conf << EOF
# zectl configuration for CachyOS
[zectl]
pool = $ZFS_POOL
boot_environment_root = $BE_ROOT
kernel_prefix = vmlinuz-
initramfs_prefix = initramfs-
unified_kernel_images = false

[bootloader]
bootloader = $BOOTLOADER
kernel_options = 
EOF

# Configure bootloader for boot environments
case "$BOOTLOADER" in
    "systemd-boot")
        log "Configuring systemd-boot for boot environment support..."
        
        # Find loader directory
        LOADER_DIR=""
        for dir in "$ESP_PATH/loader" "$ESP_PATH/EFI/systemd" "$ESP_PATH/EFI/BOOT"; do
            if [[ -d "$dir" ]]; then
                LOADER_DIR="$dir"
                break
            fi
        done
        
        if [[ -z "$LOADER_DIR" ]]; then
            LOADER_DIR="$ESP_PATH/loader"
            mkdir -p "$LOADER_DIR"
            warning "Loader directory not found, creating at $LOADER_DIR"
        fi
        
        # Backup existing loader.conf
        if [[ -f "$LOADER_DIR/loader.conf" ]]; then
            cp "$LOADER_DIR/loader.conf" "$LOADER_DIR/loader.conf.backup-$(date +%Y%m%d)"
            log "Backed up existing loader.conf"
        fi
        
        # Update loader.conf
        cat > "$LOADER_DIR/loader.conf" << EOF
default @saved
timeout 10
console-mode max
editor no
auto-entries yes
auto-firmware yes
EOF
        
        # Create entries directory
        mkdir -p "$ESP_PATH/loader/entries"
        
        success "Configured systemd-boot with increased timeout for boot environment selection"
        ;;
        
    "grub")
        log "Configuring GRUB for boot environment support..."
        warning "GRUB configuration requires manual setup. Please refer to zectl documentation."
        echo "Add the following to /etc/default/grub:"
        echo '  GRUB_CMDLINE_LINUX="zfs=$ZFS_POOL"'
        echo "Then run: grub-mkconfig -o /boot/grub/grub.cfg"
        ;;
        
    "refind")
        log "Configuring rEFInd for boot environment support..."
        warning "rEFInd configuration requires manual setup. Please refer to zectl documentation."
        ;;
        
    *)
        warning "Unknown bootloader: $BOOTLOADER. Manual configuration required."
        ;;
esac

# Enable zectl service if it exists
if systemctl list-unit-files | grep -q zectl; then
    log "Enabling zectl service..."
    systemctl enable zectl.service || warning "Failed to enable zectl service"
fi

# Create initial boot environment
log "Creating initial boot environment..."
BE_NAME="initial-$(date +%Y%m%d)"
if ! zectl list | grep -q "$BE_NAME"; then
    zectl create "$BE_NAME" || warning "Failed to create initial boot environment"
else
    log "Boot environment $BE_NAME already exists"
fi

# Generate boot entries for systemd-boot
if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    log "Generating systemd-boot entries for boot environments..."
    zectl generate-bootloader-entries || warning "Failed to generate boot entries - you may need to do this manually"
    
    # Update bootctl if available
    if command -v bootctl &>/dev/null; then
        bootctl update || warning "Failed to update systemd-boot"
    fi
fi

# Set up automatic snapshots before kernel updates
log "Setting up automatic boot environment creation before kernel updates..."
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/95-zectl-kernel.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux*
Target = *-kernel

[Action]
Description = Creating boot environment before kernel update...
When = PreTransaction
Exec = /bin/sh -c 'zectl create "pre-kernel-$(date +%Y%m%d-%H%M%S)"'
EOF

# Configure ZFS services
log "Configuring ZFS mount services..."
for service in zfs-import-cache.service zfs-mount.service zfs.target; do
    systemctl enable "$service" 2>/dev/null || warning "Failed to enable $service"
done

# Create utility script for common zectl operations
log "Creating zectl utility script..."
cat > /usr/local/bin/zectl-manager << 'EOF'
#!/bin/bash

# zectl Manager - Simplified interface for common operations

case "$1" in
    "list")
        echo "Boot Environments:"
        zectl list
        ;;
    "create")
        if [[ -z "$2" ]]; then
            echo "Usage: zectl-manager create <name>"
            exit 1
        fi
        zectl create "$2"
        echo "Created boot environment: $2"
        ;;
    "activate")
        if [[ -z "$2" ]]; then
            echo "Usage: zectl-manager activate <name>"
            exit 1
        fi
        zectl activate "$2"
        echo "Activated boot environment: $2"
        echo "Reboot to use the new boot environment"
        ;;
    "destroy")
        if [[ -z "$2" ]]; then
            echo "Usage: zectl-manager destroy <name>"
            exit 1
        fi
        read -p "Are you sure you want to destroy boot environment '$2'? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            zectl destroy "$2"
            echo "Destroyed boot environment: $2"
        else
            echo "Cancelled"
        fi
        ;;
    "snapshot")
        name="manual-$(date +%Y%m%d-%H%M%S)"
        zectl create "$name"
        echo "Created snapshot boot environment: $name"
        ;;
    "cleanup")
        echo "Cleaning old boot environments (keeping last 5)..."
        zectl list | tail -n +2 | head -n -5 | awk '{print $1}' | while read be; do
            echo "Removing old BE: $be"
            zectl destroy -r "$be" 2>/dev/null || echo "  Failed to remove $be (might be active)"
        done
        ;;
    "help"|*)
        echo "zectl Manager - Boot Environment Management"
        echo ""
        echo "Usage: zectl-manager <command> [options]"
        echo ""
        echo "Commands:"
        echo "  list                 - List all boot environments"
        echo "  create <name>        - Create new boot environment"
        echo "  activate <name>      - Activate boot environment"
        echo "  destroy <name>       - Destroy boot environment"
        echo "  snapshot             - Create timestamped snapshot"
        echo "  cleanup              - Remove old boot environments (keep last 5)"
        echo "  help                 - Show this help"
        echo ""
        echo "Direct zectl commands are also available:"
        echo "  zectl <command>      - Run zectl directly"
        ;;
esac
EOF

chmod +x /usr/local/bin/zectl-manager

# Test zectl installation
log "Testing zectl installation..."
if zectl list &> /dev/null; then
    success "zectl is working correctly!"
    echo ""
    zectl list
else
    warning "zectl may not be properly configured. Check the logs above."
fi

# System information summary
echo ""
echo "==============================================="
success "zectl installation completed!"
echo "==============================================="
echo ""
echo "System Configuration:"
echo "  ZFS Pool: $ZFS_POOL"
echo "  Boot Environment Root: $BE_ROOT"
echo "  Bootloader: $BOOTLOADER"
echo "  ESP Path: $ESP_PATH"
echo ""
echo "Next steps:"
echo "1. Reboot your system to ensure all changes take effect"
echo "2. Use 'zectl list' to see your boot environments"
echo "3. Use 'zectl-manager help' for common operations"
echo "4. Create snapshots before major system changes with 'zectl-manager snapshot'"
echo ""
echo "Boot environments will be automatically created before kernel updates."
echo ""
echo "For debugging, run with DEBUG=1 environment variable."