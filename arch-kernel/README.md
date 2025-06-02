# Arch Linux Kernel Build for s390x

This directory contains the infrastructure for building the Arch Linux kernel for IBM s390x mainframe architecture.

## Overview

The Arch Linux kernel build process has been adapted for cross-compilation to s390x. This maintains compatibility with Arch Linux's kernel patches and configuration while targeting mainframe hardware.

## Files

- `PKGBUILD-s390x` - Modified PKGBUILD for s390x cross-compilation
- `config-s390x` - Kernel configuration optimized for s390x with Arch Linux defaults
- `linux/` - Clone of Arch Linux kernel packaging repository (reference only)

## Key Differences from Standard Arch Kernel

1. **Cross-compilation**: Uses `s390x-linux-gnu-gcc` toolchain
2. **Architecture-specific config**: Includes s390x drivers (DASD, QETH, channel I/O)
3. **No documentation build**: Skipped for cross-compilation efficiency
4. **s390x boot image**: Uses `arch/s390/boot/bzImage` instead of x86 boot image

## Building

From the project root:

```bash
# Build Arch Linux kernel with patches
make arch-kernel

# Or build vanilla kernel (without Arch patches)
make kernel
```

## Configuration

The `config-s390x` file includes:

- Standard Arch Linux kernel features (systemd requirements, cgroups, namespaces)
- s390x hardware support (DASD storage, QETH networking, z/VM integration)
- IBM mainframe specific drivers and console support
- Security features (SELinux, AppArmor, BPF)

## Kernel Versions

The build process tracks the official Arch Linux kernel version and applies the same patches used in the x86_64 build.

## Integration with Project

The built kernel integrates with the existing mkinitcpio-based initramfs generation to create a complete bootable s390x system.

## Future Improvements

- Automated patch retrieval for new kernel versions
- Integration with Arch Linux package repository
- Native s390x package building (when hardware available)