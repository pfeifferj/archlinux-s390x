# Arch Linux s390x

A port of Arch Linux to IBM s390x mainframe architecture with systemd support.

Boots a full Arch Linux system on IBM mainframes (or QEMU s390x emulation) using a hybrid build: cross-compilation for the kernel, native s390x compilation on z/VM for userspace.

## Quick Start

```bash
make container        # build dev container (first time)
cp .env.example .env  # configure z/VM access
make all              # build kernel + initramfs + systemd
make test-systemd     # boot it
```

## What Works

- Arch Linux kernel 6.18.6-arch1 with Arch patches, cross-compiled
- Initramfs via modified mkinitcpio
- Static busybox built natively on z/VM, 2.3MB
- Root filesystem with ext4, switch_root to real rootfs
- Systemd as PID 1

Pacman, bash, and GNU coreutils are not yet ported.

## Build System

The build uses two tiers:

**Cross-compilation** (x86_64 host): Kernel is built in a Fedora 43 container with `s390x-linux-gnu-gcc`. Initramfs is generated with a patched mkinitcpio that handles cross-architecture binary injection.

**Native compilation** (s390x z/VM): Busybox and systemd must be built on real s390x hardware. The z/VM system runs RHEL 9.6 with GCC 11.5.0. Scripts handle SSH deployment and retrieval automatically via `.env` configuration.
