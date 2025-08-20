# zectl for CachyOS

Automated Boot Environment setup scripts for CachyOS with ZFS root filesystem. This repository provides easy-to-use scripts that automatically detect your system configuration and set up zectl (ZFS boot environment management tool) with proper integration for CachyOS.

## What This Does

- **Automatically detects** your ZFS pool, bootloader (systemd-boot/GRUB/rEFInd), and ESP path
- **Installs and configures zectl** for boot environment management
- **Sets up automatic snapshots** before kernel updates via pacman hooks
- **Optionally configures Secure Boot** with automatic kernel signing
- **Provides utility scripts** for easy management

## Prerequisites

- CachyOS installed with **ZFS root filesystem**
- UEFI boot mode (required for Secure Boot features)
- Root access to run installation scripts

## Quick Start

### 1. Install zectl

```bash
# Clone this repository
git clone https://github.com/Anonymo/zectl-for-cachyOS.git
cd zectl-for-cachyOS

# Run the installation script
sudo ./install-zectl-cachyos.sh
```

The script will:
- Auto-detect your ZFS pool and bootloader
- Build and install zectl from custom PKGBUILD (no zfs-dkms dependency)
- Configure boot environment management
- Set up automatic snapshots before kernel updates
- Create utility commands for easier management
- Generate systemd-boot entries for boot environments

### 2. Enable Secure Boot (Optional)

```bash
sudo ./setup-secureboot-cachyos.sh
```

This will:
- Install Secure Boot utilities (sbctl, sbsigntools)
- Sign your bootloader and kernels
- Set up automatic kernel signing after updates
- Provide tools to manage Secure Boot enrollment

## Post-Installation Verification

After running the installation script, verify everything is working:

### 1. Check zectl Installation
```bash
# Test zectl command
zectl list

# You should see at least one boot environment, possibly:
# - initial-YYYYMMDD (created by script)
# - Your current system environment
```

### 2. Verify systemd-boot Integration
```bash
# Check systemd-boot entries
bootctl list

# Look for boot environment entries in the systemd-boot menu
# Reboot and check the boot menu - you should see:
# - Your current CachyOS boot option
# - Additional boot environment options (if created)
# - Increased timeout (10 seconds) for selection
```

### 3. Test Boot Environment Creation
```bash
# Create a test boot environment
zectl create test-environment

# Check it appears in the list
zectl list

# Verify boot entries are updated
bootctl list
```

### 4. Verify Configuration Files
```bash
# Check zectl configuration
cat /etc/zectl/zectl.conf

# Check pacman hooks are installed
ls -la /etc/pacman.d/hooks/95-zectl-kernel.hook

# Verify custom packages are installed
pacman -Q zectl-cachyos zectl-pacman-hook-cachyos
```

## Usage

### Boot Environment Management

```bash
# List all boot environments
zectl list

# Create new boot environment
zectl create my-backup

# Activate boot environment (requires reboot)
zectl activate my-backup

# Delete boot environment
zectl destroy old-backup
```

### Simplified Commands (via zectl-manager)

```bash
# Create timestamped snapshot
zectl-manager snapshot

# List environments with better formatting
zectl-manager list

# Create and activate environment
zectl-manager create my-test
zectl-manager activate my-test

# Clean up old environments (keeps last 5)
zectl-manager cleanup

# Get help
zectl-manager help
```

### Secure Boot Management

```bash
# Check Secure Boot status
secureboot-manager status

# Verify all signatures are valid
secureboot-manager verify

# Sign all boot files manually
secureboot-manager sign-all

# Enroll keys to firmware (enables Secure Boot enforcement)
secureboot-manager enroll
```

## Automatic Features

### Pre-Kernel Update Snapshots
Boot environments are automatically created before kernel updates via pacman hook:
```
/etc/pacman.d/hooks/95-zectl-kernel.hook
```

### Automatic Kernel Signing (Secure Boot)
Kernels are automatically signed after installation via pacman hook:
```
/etc/pacman.d/hooks/99-secureboot-kernel-sign.hook
```

## Troubleshooting

### Installation Issues

**"Build fails during installation"**
- Check you have sufficient disk space in /tmp
- Ensure internet connection for downloading source code
- If custom PKGBUILD fails, the script will automatically fall back to AUR packages

**"Conflicts with existing zectl installation"**
- Remove existing packages first: `sudo pacman -R zectl-git zectl-pacman-hook`
- Then re-run the installation script

### zectl Issues

**"No boot environments found"**
- Check ZFS pool status: `zpool status`
- Verify zectl config: `cat /etc/zectl/zectl.conf`
- Check if BE root exists: `zfs list | grep ROOT`

**"Failed to activate boot environment"**
- Ensure bootloader is properly configured
- Check ESP mount: `findmnt /boot` or `findmnt /boot/efi`
- Verify bootloader entries: `bootctl list` (systemd-boot)

**"systemd-boot doesn't show boot environments"**
- Run: `zectl generate-bootloader-entries` to manually generate entries
- Check: `bootctl list` to see if entries were created
- Verify: `/boot/loader/entries/` contains `.conf` files for each boot environment
- Update: `bootctl update` to refresh systemd-boot
- If still not working, try creating a new boot environment: `zectl create test` and check again

### Secure Boot Issues

**"sbctl: command not found"**
- Install manually: `sudo pacman -S sbctl`
- Re-run setup script

**"Keys not enrolled"**
- Run: `sudo secureboot-manager enroll`
- Reboot and enable Secure Boot in UEFI settings

**"Signature verification failed"**
- Re-sign files: `sudo secureboot-manager sign-all`
- Check file permissions and ownership

### General Debugging

Enable debug output:
```bash
DEBUG=1 sudo ./install-zectl-cachyos.sh
```

Check system logs:
```bash
journalctl -u zfs-mount.service
journalctl -f | grep zectl
```

## Custom Packages

This repository includes custom PKGBUILDs optimized for CachyOS:

### zectl-cachyos
- Based on upstream zectl-git from AUR
- **Removes zfs-dkms dependency** since CachyOS has ZFS built into the kernel
- Conflicts with `zectl` and `zectl-git` to avoid duplicates
- Provides the same functionality as upstream zectl

### zectl-pacman-hook-cachyos  
- Based on upstream zectl-pacman-hook from AUR
- Depends on `zectl-cachyos` instead of `zectl`
- Automatically creates boot environments before kernel updates

## Configuration Files

| File | Purpose |
|------|---------|
| `/etc/zectl/zectl.conf` | Main zectl configuration |
| `/etc/pacman.d/hooks/95-zectl-kernel.hook` | Auto-snapshot before kernel updates |
| `/etc/pacman.d/hooks/99-secureboot-kernel-sign.hook` | Auto-sign kernels after updates |
| `/usr/local/bin/zectl-manager` | Simplified zectl interface |
| `/usr/local/bin/secureboot-manager` | Secure Boot management tool |

## Supported Configurations

### Bootloaders
- **systemd-boot** (recommended)
- **GRUB** (basic support)
- **rEFInd** (basic support)

### ZFS Pools
- Auto-detects common pool names: `zroot`, `rpool`, `tank`, `pool`
- Supports custom pool configurations

### Boot Environment Roots
- `ROOT/cachyos` (CachyOS default)
- `ROOT/arch` (Arch Linux style)
- `ROOT/default` (Generic)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on your CachyOS+ZFS system
4. Submit a pull request

## License

This project follows the same license as the original zectl project.

## Related Projects

- [zectl](https://github.com/johnramsden/zectl) - Original ZFS Boot Environment manager
- [CachyOS](https://cachyos.org/) - Arch-based distribution optimized for performance