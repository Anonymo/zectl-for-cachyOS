# zectl for CachyOS

Automated Boot Environment setup scripts for CachyOS with ZFS root filesystem. One-click installation with automatic system detection and CachyOS-optimized packages.

## Quick Start

```bash
# Clone and install
git clone https://github.com/Anonymo/zectl-for-cachyOS.git
cd zectl-for-cachyOS
sudo ./install-zectl-cachyos.sh

# Optional: Enable Secure Boot
sudo ./setup-secureboot-cachyos.sh
```

**What this does:**
- Auto-detects your ZFS pool, bootloader, and ESP path
- Installs zectl from custom PKGBUILD (no zfs-dkms dependency)
- Sets up automatic snapshots before kernel updates
- Generates systemd-boot entries for boot environments
- Creates utility scripts for easier management

<details>
<summary><strong>📋 Prerequisites</strong></summary>

- CachyOS installed with **ZFS root filesystem**
- UEFI boot mode (required for Secure Boot features)
- Root access to run installation scripts
</details>

<details>
<summary><strong>✅ Post-Installation Verification</strong></summary>

### Test zectl Installation
```bash
zectl list  # Should show at least one boot environment
```

### Verify systemd-boot Integration
```bash
bootctl list  # Should show boot environment entries
# Reboot to see boot environments in systemd-boot menu (10s timeout)
```

### Test Boot Environment Creation
```bash
zectl create test-environment
zectl list  # Should show new environment
bootctl list  # Should show updated entries
```

### Verify Packages
```bash
pacman -Q zectl-cachyos zectl-pacman-hook-cachyos
```
</details>

<details>
<summary><strong>🚀 Usage</strong></summary>

### Basic Commands
```bash
# List environments
zectl list

# Create environment
zectl create my-backup

# Activate environment (requires reboot)
zectl activate my-backup

# Delete environment
zectl destroy old-backup
```

### Simplified Commands (zectl-manager)
```bash
zectl-manager snapshot     # Create timestamped snapshot
zectl-manager list         # Better formatted list
zectl-manager cleanup      # Remove old environments (keep last 5)
zectl-manager help         # Show all commands
```

### Secure Boot Commands
```bash
secureboot-manager status    # Check Secure Boot status
secureboot-manager verify    # Verify signatures
secureboot-manager enroll    # Enroll keys to firmware
```
</details>

<details>
<summary><strong>⚡ Automatic Features</strong></summary>

- **Pre-kernel snapshots**: Automatic boot environments before kernel updates
- **Secure Boot signing**: Automatic kernel signing after updates (if enabled)
- **Boot entry generation**: systemd-boot entries automatically created/updated
</details>

<details>
<summary><strong>🔧 Troubleshooting</strong></summary>

### Installation Issues
- **Build fails**: Check disk space in `/tmp`, internet connection
- **Package conflicts**: Remove existing packages: `sudo pacman -R zectl-git zectl-pacman-hook`

### Boot Environment Issues
- **Not showing in systemd-boot**: Run `zectl generate-bootloader-entries` and `bootctl update`
- **zectl command fails**: Check ZFS pool status: `zpool status`
- **No environments found**: Verify config: `cat /etc/zectl/zectl.conf`

### System Issues After Installation
- **Sleep/wake problems**: ZFS services might interfere with power management
  - Check ZFS service status: `systemctl status zfs-import-cache.service zfs-mount.service`
  - Disable problematic services temporarily: `sudo systemctl disable zfs-import-cache.service`
  - Check system logs: `journalctl -b | grep -i "suspend\|sleep\|wake"`

### Debug Mode
```bash
DEBUG=1 sudo ./install-zectl-cachyos.sh
```

### System Diagnostic
```bash
# Run comprehensive system diagnostic
./diagnose-system.sh
```
</details>

<details>
<summary><strong>📦 Custom Packages</strong></summary>

### zectl-cachyos
- Based on upstream zectl-git
- **No zfs-dkms dependency** (CachyOS has ZFS built-in)
- Conflicts with `zectl` and `zectl-git`

### zectl-pacman-hook-cachyos  
- Depends on `zectl-cachyos`
- Automatic boot environments before kernel updates
</details>

<details>
<summary><strong>⚙️ Configuration Files</strong></summary>

| File | Purpose |
|------|---------|
| `/etc/zectl/zectl.conf` | Main zectl configuration |
| `/etc/pacman.d/hooks/95-zectl-kernel.hook` | Auto-snapshot before kernel updates |
| `/etc/pacman.d/hooks/99-secureboot-kernel-sign.hook` | Auto-sign kernels (Secure Boot) |
| `/usr/local/bin/zectl-manager` | Simplified interface |
| `/usr/local/bin/secureboot-manager` | Secure Boot management |
</details>

<details>
<summary><strong>🔗 Related Projects</strong></summary>

- [zectl](https://github.com/johnramsden/zectl) - Original ZFS Boot Environment manager
- [CachyOS](https://cachyos.org/) - Performance-optimized Arch Linux distribution
</details>