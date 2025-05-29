# Arch Linux s390x LPAR Boot Components

This repository contains the necessary files to boot Arch Linux on IBM System z (s390x) LPAR.

## Structure

```
.
├── s390x/
│   └── boot/
│       ├── arch.prm              # Kernel parameters
│       ├── initrd.addrsize       # Memory layout for initrd
│       ├── vmlinuz-linux         # s390x kernel (needs to be added)
│       └── initramfs-linux.img   # s390x initrd (needs to be added)
├── generic.ins                   # IPL configuration file
├── .treeinfo                     # Boot media metadata
└── README.md                     # This file
```

## Boot Files

- **generic.ins** - IPL configuration file that specifies:
  - Kernel location: `s390x/boot/vmlinuz-linux` at address `0x00000000`
  - Initrd location: `s390x/boot/initramfs-linux.img` at address `0x02000000`
  - Parameter file: `s390x/boot/arch.prm`
  - Address/size file: `s390x/boot/initrd.addrsize`

- **arch.prm** - Kernel boot parameters:
  - Console settings for both serial and virtual terminals
  - Arch ISO base directory and label

- **initrd.addrsize** - Memory layout:
  - Start address: `0x02000000`
  - Maximum size: `0x10000000` (256MB)

- **.treeinfo** - Boot media metadata for SFTP boot

## Todo

1. Build or obtain s390x versions of:
   - Linux kernel compiled for s390x
   - Initramfs with s390x userspace
