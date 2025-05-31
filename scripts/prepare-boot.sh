#!/bin/bash
# Prepare boot directory with built kernel and initramfs

set -e

# Configuration
KERNEL_VERSION="${KERNEL_VERSION:-6.6.10}"
OUTPUT_DIR="output"
BOOT_DIR="boot"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Preparing s390x boot directory ===${NC}"

# Check if kernel exists
if [ ! -f "$OUTPUT_DIR/vmlinuz-${KERNEL_VERSION}-s390x" ]; then
    echo -e "${RED}Error: Kernel not found. Run 'make kernel' first${NC}"
    exit 1
fi

# Check if initramfs exists
INITRAMFS=""
for img in "$OUTPUT_DIR/initramfs-${KERNEL_VERSION}-s390x.img" \
           "$OUTPUT_DIR/initramfs-${KERNEL_VERSION}-s390x-manual.img"; do
    if [ -f "$img" ]; then
        INITRAMFS="$img"
        break
    fi
done

if [ -z "$INITRAMFS" ]; then
    echo -e "${RED}Error: Initramfs not found. Run 'make initramfs' first${NC}"
    exit 1
fi

# Copy kernel to boot directory
echo -e "${YELLOW}Copying kernel...${NC}"
cp "$OUTPUT_DIR/vmlinuz-${KERNEL_VERSION}-s390x" "$BOOT_DIR/vmlinuz-linux"

# Copy initramfs to boot directory
echo -e "${YELLOW}Copying initramfs...${NC}"
cp "$INITRAMFS" "$BOOT_DIR/initramfs-linux.img"

# Update generic.ins if needed
echo -e "${YELLOW}Updating generic.ins...${NC}"
cat > "$BOOT_DIR/generic.ins" << EOF
* Arch Linux for s390x - IPL from generic device
* 
vmlinuz-linux 0x00000000
initramfs-linux.img 0x02000000
arch.prm
initrd.addrsize
EOF

# Create .treeinfo for SFTP boot
echo -e "${YELLOW}Creating .treeinfo...${NC}"
cat > "$BOOT_DIR/.treeinfo" << EOF
[general]
name = Arch Linux
family = Arch Linux
version = Rolling
arch = s390x
platforms = s390x

[images-s390x]
kernel = vmlinuz-linux
initrd = initramfs-linux.img
generic.prm = arch.prm
generic.ins = generic.ins
initrd.addrsize = initrd.addrsize
EOF

# Create a boot info file
echo -e "${YELLOW}Creating boot info...${NC}"
cat > "$BOOT_DIR/boot-info.txt" << EOF
Arch Linux s390x Boot Directory
==============================

Kernel Version: ${KERNEL_VERSION}
Build Date: $(date)
Architecture: s390x

Files:
- vmlinuz-linux: Linux kernel for s390x
- initramfs-linux.img: Initial RAM filesystem
- generic.ins: IPL configuration file
- arch.prm: Kernel boot parameters
- initrd.addrsize: Memory layout for initrd

To boot on real s390x hardware:
1. Transfer this boot directory to your z/VM or LPAR system
2. Use FTP or SFTP to copy files to the target system
3. IPL from the device containing these files
4. For z/VM: Use the generic.ins file for IPL

For QEMU testing:
  make test
EOF

echo -e "${GREEN}✓ Boot directory prepared successfully!${NC}"
echo -e "${GREEN}Boot files are in: $BOOT_DIR/${NC}"
ls -la "$BOOT_DIR/"
#