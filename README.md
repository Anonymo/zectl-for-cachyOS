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
- Install zectl from AUR
- Configure boot environment management
- Set up automatic snapshots before kernel updates
- Create utility commands for easier management

### 2. Enable Secure Boot (Optional)

```bash
sudo ./setup-secureboot-cachyos.sh
```

This will:
- Install Secure Boot utilities (sbctl, sbsigntools)
- Sign your bootloader and kernels
- Set up automatic kernel signing after updates
- Provide tools to manage Secure Boot enrollment

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

**"Password required for user 'nobody'"**
- This is automatically handled by the script using available user accounts
- If you see this prompt, the script will create a temporary build user
- No action needed - just wait for the script to continue

### zectl Issues

**"No boot environments found"**
- Check ZFS pool status: `zpool status`
- Verify zectl config: `cat /etc/zectl/zectl.conf`
- Check if BE root exists: `zfs list | grep ROOT`

**"Failed to activate boot environment"**
- Ensure bootloader is properly configured
- Check ESP mount: `findmnt /boot` or `findmnt /boot/efi`
- Verify bootloader entries: `bootctl list` (systemd-boot)

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