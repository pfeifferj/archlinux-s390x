#!/bin/bash
# Test s390x Arch Linux with systemd as init

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Arch Linux s390x - Systemd Test"
echo "This will boot with systemd as PID 1"
echo "Press Ctrl-A X to exit"
echo ""

cd "$PROJECT_ROOT"

# Check if systemd is available
if [ ! -d "output/systemd-root" ]; then
    echo "Error: Systemd not found. Run 'make systemd' first"
    exit 1
fi

# Create systemd-enabled root filesystem directly
echo "Preparing systemd-enabled root filesystem..."

ROOTFS_IMG="boot/rootfs-s390x.img"

# Force recreation of root filesystem
rm -f "$ROOTFS_IMG"

# Create 150MB root filesystem image (for systemd)
dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count=150

# Format as ext4
mkfs.ext4 -F "$ROOTFS_IMG"

# Mount and populate
mkdir -p /tmp/rootfs-mount
sudo mount -o loop "$ROOTFS_IMG" /tmp/rootfs-mount

# Create basic directory structure
sudo mkdir -p /tmp/rootfs-mount/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/{bin,sbin},lib,lib64}

# Copy busybox as fallback
sudo cp boot/busybox-s390x-static /tmp/rootfs-mount/bin/busybox
sudo chroot /tmp/rootfs-mount /bin/busybox --install -s

# Install systemd
echo "Installing systemd to root filesystem..."
sudo cp -r output/systemd-root/* /tmp/rootfs-mount/

# Create systemd directories
sudo mkdir -p /tmp/rootfs-mount/run/systemd
sudo mkdir -p /tmp/rootfs-mount/var/log/journal
sudo mkdir -p /tmp/rootfs-mount/etc/systemd/system
sudo mkdir -p /tmp/rootfs-mount/sys
sudo mkdir -p /tmp/rootfs-mount/proc

# Create device nodes
sudo mknod /tmp/rootfs-mount/dev/console c 5 1 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty c 5 0 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty1 c 4 1 2>/dev/null || true

# Create basic files
sudo tee /tmp/rootfs-mount/etc/passwd > /dev/null << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

sudo tee /tmp/rootfs-mount/etc/group > /dev/null << 'EOF'
root:x:0:
EOF

sudo tee /tmp/rootfs-mount/etc/os-release > /dev/null << 'EOF'
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
EOF

sudo tee /tmp/rootfs-mount/etc/hostname > /dev/null << 'EOF'
archlinux-s390x
EOF

# Unmount
sudo umount /tmp/rootfs-mount
rmdir /tmp/rootfs-mount

echo "✓ Root filesystem with systemd prepared"

# Run QEMU with systemd as init
echo "Booting with systemd..."
qemu-system-s390x \
    -M s390-ccw-virtio \
    -cpu qemu \
    -m 2G \
    -smp 1 \
    -kernel boot/vmlinuz-linux \
    -initrd boot/initramfs-linux.img \
    -append "console=ttyS0 root=/dev/vda rw init=/usr/lib/systemd/systemd systemd.log_level=debug" \
    -drive file=boot/rootfs-s390x.img,format=raw,if=virtio \
    -netdev user,id=network0 \
    -device virtio-net,netdev=network0 \
    -nographic \
    -serial mon:stdio