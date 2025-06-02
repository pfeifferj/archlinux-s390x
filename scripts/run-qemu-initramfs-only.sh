#!/bin/bash
# Complete s390x Arch Linux system running from initramfs only

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Arch Linux s390x - Initramfs Only System"
echo "This will boot entirely from the initramfs (no separate root filesystem)"
echo "Press Ctrl-A X to exit"
echo ""

cd "$PROJECT_ROOT"

qemu-system-s390x \
    -machine s390-ccw-virtio \
    -cpu max \
    -m 2G \
    -kernel "boot/vmlinuz-linux" \
    -initrd "boot/initramfs-linux.img" \
    -append "console=ttyS0 rdinit=/init" \
    -nographic \
    -device virtio-net-ccw,netdev=net0 \
    -netdev user,id=net0
