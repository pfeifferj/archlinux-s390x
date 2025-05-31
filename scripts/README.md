# Arch Linux s390x Build Scripts

The project focuses on a **single proven approach**: using modified Arch Linux mkinitcpio with s390x support.

### Core Build Workflow (7 scripts)
1. `install-toolchain-fedora-kernel.sh` - Install s390x cross-compilation toolchain via Fedora container
2. `build-kernel-container.sh` - Build Linux kernel in Fedora container
3. `build-mkinitcpio-container.sh` - Build container with upgraded meson for mkinitcpio ⭐
4. `build-initramfs-final.sh` - **MAIN METHOD**: Build initramfs using modified mkinitcpio ⭐
5. `prepare-boot.sh` - Prepare boot directory with kernel, initramfs, and IPL files
6. `test-qemu.sh` - Test the built system with QEMU s390x emulation
7. `setup-path.sh` - Add toolchain wrappers to PATH (used by build-all.sh)

## Modified mkinitcpio Implementation ⭐

**Key Features**:
- s390x-specific configuration (`mkinitcpio-s390x.conf`)
- Works with Fedora containers using upgraded meson (1.8.1)
- Proper s390x module support (DASD, QETH, virtio devices)
- Solves cross-compilation header issues that plagued busybox approaches
