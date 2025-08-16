# zectl for CachyOS

Boot Environment setup scripts for CachyOS with ZFS root

## Installation

### Install zectl

```bash
sudo ./install-zectl-cachyos.sh
```

### Enable Secure Boot (Optional)

```bash
sudo ./setup-secureboot-cachyos.sh
```

## Usage

### Boot Environments

```bash
# List boot environments
zectl list

# Create new boot environment
zectl create backup-name

# Activate boot environment
zectl activate backup-name

# Delete boot environment
zectl destroy old-backup
```

### Quick Commands

```bash
# Create snapshot with timestamp
zectl-manager snapshot

# List environments
zectl-manager list

# Help
zectl-manager help
```

### Secure Boot

```bash
# Check status
secureboot-manager status

# Verify signed files
secureboot-manager verify

# Sign all kernels
secureboot-manager sign-all
```

## Files

- `install-zectl-cachyos.sh` - Installs zectl and configures boot environments
- `setup-secureboot-cachyos.sh` - Configures Secure Boot with automatic kernel signing