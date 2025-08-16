# zectl for CachyOS

Boot Environment Management and Secure Boot Setup for CachyOS with ZFS Root

## Overview

This repository provides automated scripts to set up and manage ZFS Boot Environments (BE) on CachyOS systems using `zectl`, along with Secure Boot configuration. Boot Environments allow you to create snapshots of your entire system before major changes, enabling easy rollback if something goes wrong.

## Features

- **Automated zectl Installation**: Complete setup of zectl boot environment manager for CachyOS
- **Secure Boot Support**: Full Secure Boot configuration with automatic kernel signing
- **Automatic Snapshots**: Creates boot environments automatically before kernel updates
- **systemd-boot Integration**: Seamless integration with systemd-boot bootloader
- **User-Friendly Management**: Simple commands for common boot environment operations

## Prerequisites

- CachyOS installed with ZFS root filesystem
- UEFI boot mode (required for Secure Boot)
- Root access to run installation scripts

## Installation

### Step 1: Install zectl

Run the installation script to set up zectl and configure boot environment management:

```bash
sudo ./install-zectl-cachyos.sh
```

This script will:
- Install zectl from AUR
- Configure zectl for your ZFS root pool
- Set up systemd-boot integration
- Create pacman hooks for automatic snapshots
- Install management utilities

### Step 2: Enable Secure Boot (Optional)

If you want to enable Secure Boot support:

```bash
sudo ./setup-secureboot-cachyos.sh
```

This script will:
- Create and enroll Secure Boot keys
- Sign all kernels and bootloader
- Set up automatic signing for new kernels
- Configure boot entries for signed kernels

## Usage

### Boot Environment Management

List all boot environments:
```bash
zectl list
```

Create a new boot environment:
```bash
zectl create my-backup
```

Activate a boot environment:
```bash
zectl activate my-backup
```

Delete a boot environment:
```bash
zectl destroy old-backup
```

### Quick Management Commands

The installation provides a simplified management interface:

```bash
# List boot environments
zectl-manager list

# Create timestamped snapshot
zectl-manager snapshot

# Activate a boot environment
zectl-manager activate <name>

# Delete a boot environment
zectl-manager destroy <name>
```

### Secure Boot Management

Check Secure Boot status:
```bash
secureboot-manager status
```

Verify all signed files:
```bash
secureboot-manager verify
```

Re-sign all kernels:
```bash
secureboot-manager sign-all
```

## Automatic Features

### Kernel Update Protection

The system automatically creates a boot environment before kernel updates, allowing you to roll back if the new kernel causes issues.

### Secure Boot Kernel Signing

When Secure Boot is enabled, new kernels are automatically signed during installation, ensuring they can boot with Secure Boot enabled.

## Boot Environment Workflow

1. **Before System Updates**: A boot environment is automatically created
2. **Testing Changes**: Boot into the new environment to test
3. **Rollback if Needed**: If issues occur, activate the previous boot environment and reboot
4. **Cleanup**: Delete old boot environments when no longer needed

## Troubleshooting

### Boot Environment Not Listed

Ensure ZFS services are enabled:
```bash
sudo systemctl enable zfs-mount.service
sudo systemctl enable zfs.target
```

### Secure Boot Verification Failed

Re-sign all kernels:
```bash
sudo secureboot-manager sign-all
```

### Cannot Create Boot Environment

Check available space:
```bash
zfs list -o name,used,avail
```

## File Structure

```
.
├── install-zectl-cachyos.sh      # Main installation script
├── setup-secureboot-cachyos.sh   # Secure Boot configuration
└── README.md                      # This file
```

## System Requirements

- **Minimum**: 2GB RAM, 20GB storage (with ZFS)
- **Recommended**: 4GB RAM, 50GB+ storage for multiple boot environments
- **ZFS Pool**: Must have sufficient free space for snapshots

## Safety Features

- Automatic backups of configuration files
- Non-destructive installation process
- Verification steps after each major operation
- Clear error messages and recovery instructions

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve these scripts.

## License

This project is provided as-is for the CachyOS community. Feel free to use and modify according to your needs.

## Support

For issues specific to:
- **zectl**: Check the [zectl documentation](https://github.com/johnramsden/zectl)
- **CachyOS**: Visit the [CachyOS forums](https://forum.cachyos.org/)
- **These scripts**: Open an issue in this repository

## Acknowledgments

- CachyOS team for their excellent Arch-based distribution
- zectl developers for the boot environment management tool
- ZFS on Linux community for making this possible