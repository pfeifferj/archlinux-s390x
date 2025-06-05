# Arch Linux s390x Port with Systemd

This repository contains a **complete, working** s390x Arch Linux system with **systemd support** and full root filesystem that boots successfully on IBM mainframes and QEMU emulation.

## Quick Start

```bash
# Build everything
make all

# Test initramfs-only system
make test

# Test with root filesystem
make test-rootfs

# Test with systemd as init
make test-systemd
```

## What's Working

- **Arch Linux Kernel**: Linux 6.6.10 with Arch patches and CONFIG_UNIX/CONFIG_KMOD support (5.8MB)
- **Initramfs**: Complete 5.9MB initramfs with s390x busybox
- **Boot Process**: Successful boot to root filesystem with busybox shell
- **Root Filesystem**: **COMPLETE!** 150MB ext4 root filesystem with Arch Linux identification
- **Systemd**: **WORKING!** 42MB minimal systemd with mount/udevadm utilities - boots to "Welcome to Arch Linux!"
- **Modern Init**: Full systemd boot reaching Multi-User and Graphical targets
- **QEMU Testing**: Fully functional in s390x emulation
- **Ready for Hardware**: IPL configuration for real mainframes

## Build Status

### Core System Components
| Component | Status | Details |
|-----------|--------|---------|
| Kernel | ✅ Working | 5.8MB bootable s390x kernel with CONFIG_UNIX/CONFIG_KMOD (6.6.10) |
| Initramfs | ✅ Working | 5.9MB with native s390x binaries |
| Boot Process | ✅ Working | IPL → kernel → initramfs → root filesystem → systemd |
| Root Filesystem | ✅ **COMPLETE** | 150MB ext4 with working busybox switch_root |
| Systemd | ✅ **WORKING** | 42MB minimal systemd with mount/udevadm - reaches graphical target |
| mkinitcpio | ✅ Fixed | Adapted for s390x architecture |

### Userspace Components
| Component | Status | Details |
|-----------|--------|---------|
| Init System | ✅ **COMPLETE** | Busybox in initramfs → switch_root → systemd |
| Shell | 🟨 Minimal | Busybox sh (not bash) |
| Core Utilities | ✅ **Enhanced** | Busybox applets + mount/udevadm/kmod utilities |
| Package Manager | ❌ TODO | Pacman needs porting |
| Systemd Runtime | ✅ **WORKING** | Full systemd boot with journal, udev, and basic services |
| Bash | ❌ TODO | Needs s390x build |
| GNU Coreutils | ❌ TODO | Replace busybox applets |

### Legend
- ✅ **Complete** - Fully working
- 🟨 **Minimal** - Working but minimal implementation
- ❌ **TODO** - Not yet implemented

## Build System

Uses **Fedora containers with Podman** for cross-compilation:

```bash
# Container image:
s390x-archlinux-dev          # All-in-one development container
```

### Build Targets:
- `make all` - Build complete system (kernel + initramfs + systemd)
- `make kernel` - Cross-compile Arch Linux kernel for s390x
- `make initramfs` - Generate initramfs with mkinitcpio
- `make systemd` - Build systemd natively on z/VM (requires .env configuration)
- `make test` - Test initramfs-only system with QEMU
- `make test-rootfs` - Test with root filesystem switching
- `make test-systemd` - Test with systemd as init (full modern boot)
- `make clean` - Clean build artifacts

### Key Scripts:
- `scripts/build-arch-kernel.sh` - Cross-compile Arch Linux kernel
- `scripts/build-initramfs-final.sh` - Generate initramfs
- `scripts/build-systemd-zvm.sh` - Build systemd on z/VM
- `scripts/deploy-and-build-systemd-zvm.sh` - Orchestrate systemd build
- `scripts/run-qemu-initramfs-only.sh` - Test initramfs-only system
- `scripts/test-qemu-rootfs.sh` - Test with root filesystem
- `scripts/test-qemu-systemd.sh` - Test with systemd as init
- `scripts/build-busybox-zvm.sh` - Build static busybox on z/VM

## z/VM Configuration

For building systemd and busybox natively on s390x hardware, you'll need access to an IBM z/VM system:

1. **Copy the example configuration**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your z/VM details**:
   ```bash
   ZVM_HOST=your.zvm.host
   ZVM_USER=your_username
   ZVM_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
   ... your SSH private key content ...
   -----END OPENSSH PRIVATE KEY-----"
   ```

3. **Build systemd**:
   ```bash
   make systemd
   ```

The scripts will automatically load the `.env` configuration when needed.

## Testing

```bash
# Install QEMU s390x
sudo pacman -S qemu-system-s390x  # Arch Linux
# or
sudo apt install qemu-system-s390x # Ubuntu/Debian

# Test initramfs-only system
make test

# Test root filesystem switching
make test-rootfs

# Test full systemd boot (requires systemd build)
make test-systemd
```

**Expected Results**: 
- `make test` - System boots to emergency shell in initramfs-only mode (press Ctrl-A X to exit)
- `make test-rootfs` - Boots completely to root filesystem with busybox shell
- `make test-systemd` - Full systemd boot reaching "Welcome to Arch Linux!" and graphical target

[![asciicast](https://asciinema.org/a/u49jp0Bg7YoGtlGyTh6C9RJ7P.svg)](https://asciinema.org/a/u49jp0Bg7YoGtlGyTh6C9RJ7P)

## Output Files

After building:
- `boot/vmlinuz-linux` - Ready-to-use s390x kernel
- `boot/initramfs-linux.img` - Working initramfs  
- `boot/rootfs-s390x.img` - Root filesystem image (created by test-rootfs)
- `boot/generic.ins` - IPL configuration for real hardware
- `boot/arch.prm` - Kernel parameters
- `boot/busybox-s390x-static` - Static busybox binary built on z/VM (used by mkinitcpio)
- `output/systemd-root/` - Complete systemd installation for root filesystem

## Technical Details

### s390x Adaptations:
- Big-endian architecture support
- IPL boot process (not BIOS/UEFI)
- Channel I/O subsystem drivers
- mkinitcpio modified for cross-architecture builds

### Key Fixes Applied:
1. **mkinitcpio adaptation** - Fixed `add_binary` vs `add_file` issue for init scripts
2. **Static busybox in initramfs** - Built natively on z/VM for early boot operations
3. **Architecture compatibility** - Fixed base hook to exclude x86_64 binaries
4. **switch_root support** - Enables transition from initramfs to systemd on root filesystem
5. **Kernel configuration** - Added CONFIG_UNIX and CONFIG_KMOD for systemd support

## System Boot Sequence

The complete boot process follows this sequence:

1. **IPL (Initial Program Load)** - IBM mainframe boot process
2. **Kernel loads** - Linux 6.6.10 s390x kernel with Arch patches
3. **Initramfs unpacked** - Contains busybox and init script
4. **Early boot** - Busybox provides utilities for mounting and setup
5. **Root filesystem mounted** - `/dev/vda` mounted to `/new_root`
6. **switch_root** - Busybox `switch_root` transitions to real root filesystem
7. **Systemd starts** - `/usr/lib/systemd/systemd` becomes PID 1
