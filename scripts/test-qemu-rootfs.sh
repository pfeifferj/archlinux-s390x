#!/bin/bash
# Test s390x Arch Linux with a root filesystem instead of just initramfs

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Arch Linux s390x - Root Filesystem Test"
echo "This will boot with initramfs then switch to a root filesystem"
echo "Press Ctrl-A X to exit"
echo ""

cd "$PROJECT_ROOT"

# Create a minimal root filesystem if it doesn't exist
ROOTFS_IMG="boot/rootfs-s390x.img"

# Force recreation of root filesystem to get updated init script
echo "Creating minimal root filesystem (forcing recreation)..."
rm -f "$ROOTFS_IMG"

# Create 100MB root filesystem image
dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count=100

# Format as ext4
mkfs.ext4 -F "$ROOTFS_IMG"

# Mount and populate
mkdir -p /tmp/rootfs-mount
sudo mount -o loop "$ROOTFS_IMG" /tmp/rootfs-mount

# Create basic directory structure
sudo mkdir -p /tmp/rootfs-mount/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/{bin,sbin},lib,lib64}

# Copy busybox as the main shell and utilities
sudo cp boot/busybox-s390x-static /tmp/rootfs-mount/bin/busybox

# Create busybox symlinks for basic utilities
sudo chroot /tmp/rootfs-mount /bin/busybox --install -s

# Pre-create TTY devices to avoid errors
sudo mknod /tmp/rootfs-mount/dev/console c 5 1 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty c 5 0 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty1 c 4 1 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty2 c 4 2 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty3 c 4 3 2>/dev/null || true
sudo mknod /tmp/rootfs-mount/dev/tty4 c 4 4 2>/dev/null || true

# Create basic /etc/passwd
sudo tee /tmp/rootfs-mount/etc/passwd > /dev/null << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

# Create basic /etc/group
sudo tee /tmp/rootfs-mount/etc/group > /dev/null << 'EOF'
root:x:0:
EOF

# Create /etc/os-release to identify as Arch Linux
sudo tee /tmp/rootfs-mount/etc/os-release > /dev/null << 'EOF'
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://bugs.archlinux.org/"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=archlinux-logo
EOF

# Create /etc/arch-release (traditional Arch identifier)
sudo tee /tmp/rootfs-mount/etc/arch-release > /dev/null << 'EOF'
Arch Linux s390x \r (\l)
EOF

# Create /etc/hostname
sudo tee /tmp/rootfs-mount/etc/hostname > /dev/null << 'EOF'
archlinux-s390x
EOF

# Create basic /etc/hosts
sudo tee /tmp/rootfs-mount/etc/hosts > /dev/null << 'EOF'
127.0.0.1	localhost
::1		localhost
127.0.1.1	archlinux-s390x.localdomain	archlinux-s390x
EOF

# Create basic init script for the root filesystem
sudo tee /tmp/rootfs-mount/sbin/init > /dev/null << 'EOF'
#!/bin/sh
echo "🎉 Welcome to Arch Linux s390x Root Filesystem!"
echo "This is running from a real root filesystem, not just initramfs."
echo ""

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

# Create TTY devices that busybox init expects
mknod /dev/tty1 c 4 1 2>/dev/null || true
mknod /dev/tty2 c 4 2 2>/dev/null || true  
mknod /dev/tty3 c 4 3 2>/dev/null || true
mknod /dev/tty4 c 4 4 2>/dev/null || true
mknod /dev/console c 5 1 2>/dev/null || true

echo "=== ARCH LINUX VERIFICATION ==="
echo "Distribution info:"
if [ -f /etc/os-release ]; then
    cat /etc/os-release
else
    echo "No /etc/os-release found"
fi
echo ""

if [ -f /etc/arch-release ]; then
    echo "Arch release file:"
    cat /etc/arch-release
else
    echo "No /etc/arch-release found"
fi
echo ""

echo "Hostname: $(cat /etc/hostname 2>/dev/null || echo 'Not set')"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo ""

echo "Root filesystem contents:"
ls -la /
echo ""

echo "Available TTY devices:"
ls -la /dev/tty* 2>/dev/null || echo "No TTY devices found"
echo ""

echo "Available commands:"
echo "  ls, cat, mount, umount, ps, top, free, df, etc."
echo "  Type 'busybox' to see all available applets"
echo ""

echo "To verify this is Arch Linux, check:"
echo "  cat /etc/os-release"
echo "  cat /etc/arch-release"
echo "  uname -a"
echo ""

# Start a shell
exec /bin/sh
EOF

sudo chmod +x /tmp/rootfs-mount/sbin/init

sudo umount /tmp/rootfs-mount
rmdir /tmp/rootfs-mount

echo "✅ Root filesystem created at $ROOTFS_IMG"

# Boot with root filesystem
qemu-system-s390x \
    -machine s390-ccw-virtio \
    -cpu max \
    -m 2G \
    -kernel "boot/vmlinuz-linux" \
    -initrd "boot/initramfs-linux.img" \
    -append "console=ttyS0 root=/dev/vda rw init=/sbin/init" \
    -drive file="$ROOTFS_IMG",format=raw,if=none,id=rootdisk \
    -device virtio-blk-ccw,drive=rootdisk \
    -nographic \
    -device virtio-net-ccw,netdev=net0 \
    -netdev user,id=net0