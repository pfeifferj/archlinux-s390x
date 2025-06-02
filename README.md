# Arch Linux s390x Port 

This repository contains a **complete, working** s390x Arch Linux system with full root filesystem support that boots successfully on IBM mainframes and QEMU emulation.

## Quick Start

```bash
# Build everything
make all

# Test initramfs-only system
make test

# Test with root filesystem
make test-rootfs
```

## What's Working

- **s390x Kernel**: Linux 6.6.10 cross-compiled for IBM mainframes (11MB)
- **Initramfs**: Complete 5.9MB initramfs with s390x busybox
- **Boot Process**: Successful boot to root filesystem with busybox shell
- **Root Filesystem**: **COMPLETE!** 100MB ext4 root filesystem with Arch Linux identification
- **QEMU Testing**: Fully functional in s390x emulation
- **Ready for Hardware**: IPL configuration for real mainframes

## Build Status

### Core System Components
| Component | Status | Details |
|-----------|--------|---------|
| Kernel | ✅ Working | 11MB bootable s390x kernel (vanilla 6.6.10) |
| Initramfs | ✅ Working | 5.9MB with native s390x binaries |
| Boot Process | ✅ Working | IPL → kernel → initramfs → root filesystem |
| Root Filesystem | ✅ **COMPLETE** | 100MB ext4 with working busybox switch_root |
| mkinitcpio | ✅ Fixed | Adapted for s390x architecture |

### Userspace Components
| Component | Status | Details |
|-----------|--------|---------|
| Init System | 🟨 Minimal | Busybox init (not systemd) |
| Shell | 🟨 Minimal | Busybox sh (not bash) |
| Core Utilities | 🟨 Minimal | Busybox applets only |
| Package Manager | ❌ TODO | Pacman needs porting |
| Systemd | ❌ TODO | Requires cross-compilation |
| Bash | ❌ TODO | Needs s390x build |
| GNU Coreutils | ❌ TODO | Replace busybox applets |
| Arch Kernel Patches | ❌ TODO | Apply Arch-specific patches |

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
- `make all` - Build complete system (kernel + initramfs)
- `make kernel` - Cross-compile s390x kernel only
- `make initramfs` - Generate initramfs with mkinitcpio
- `make test` - Test initramfs-only system with QEMU
- `make test-rootfs` - Test with root filesystem switching
- `make clean` - Clean build artifacts

### Key Scripts:
- `scripts/build-kernel-container.sh` - Cross-compile kernel
- `scripts/build-initramfs-final.sh` - Generate initramfs
- `scripts/run-qemu-initramfs-only.sh` - Test initramfs-only system
- `scripts/test-qemu-rootfs.sh` - Test with root filesystem
- `scripts/build-busybox-zvm.sh` - Build static busybox on z/VM

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
```

**Expected**: 
- `make test` - System boots to emergency shell in initramfs-only mode (press Ctrl-A X to exit)
- `make test-rootfs` - Boots completely to root filesystem with busybox shell

[![asciicast](https://asciinema.org/a/QVmnI1tyJjjFp4cps93qiTbM9.svg)](https://asciinema.org/a/QVmnI1tyJjjFp4cps93qiTbM9)

## Output Files

After building:
- `boot/vmlinuz-linux` - Ready-to-use s390x kernel
- `boot/initramfs-linux.img` - Working initramfs  
- `boot/rootfs-s390x.img` - Root filesystem image (created by test-rootfs)
- `boot/generic.ins` - IPL configuration for real hardware
- `boot/arch.prm` - Kernel parameters
- `boot/busybox-s390x-static` - Static busybox binary built on z/VM

## Technical Details

### s390x Adaptations:
- Big-endian architecture support
- IPL boot process (not BIOS/UEFI)
- Channel I/O subsystem drivers
- mkinitcpio modified for cross-architecture builds

### Key Fixes Applied:
1. **mkinitcpio adaptation** - Fixed `add_binary` vs `add_file` issue for init scripts
2. **Static busybox** - Built natively on z/VM to eliminate dynamic linking
3. **Architecture compatibility** - Fixed base hook to exclude x86_64 binaries
4. **Init script patching** - Modified standard Arch init to use `busybox switch_root`

## System Boot Success

The system successfully boots from initramfs to root filesystem:

```
[   22.867595] Run /init as init process
:: mounting '/dev/vda' on real root
[   23.131648] EXT4-fs (vda): mounted filesystem r/w with ordered data mode
/ # cat /etc/os-release
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch

/ # uname -a
Linux arch 6.6.10 #14 SMP Mon Jun  2 14:59:34 UTC 2025 s390x GNU/Linux
```
