#!/bin/bash
# Test s390x kernel and initramfs with QEMU

set -e

# Configuration
OUTPUT_DIR="output"
KERNEL_VERSION="${KERNEL_VERSION:-6.6.10}"
QEMU_MEM="${QEMU_MEM:-2G}"
QEMU_CPU="${QEMU_CPU:-max}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Testing s390x build with QEMU ===${NC}"

# Check for qemu-system-s390x
if ! command -v qemu-system-s390x &> /dev/null; then
    echo -e "${RED}Error: qemu-system-s390x not found${NC}"
    echo "Install with:"
    echo "  Arch: sudo pacman -S qemu-system-s390x"
    echo "  Ubuntu/Debian: sudo apt-get install qemu-system-s390x"
    echo "  Fedora: sudo dnf install qemu-system-s390x"
    exit 1
fi

# Check if boot directory is prepared
if [ -f "boot/vmlinuz-linux" ] && [ -f "boot/initramfs-linux.img" ]; then
    echo -e "${GREEN}Using prepared boot directory${NC}"
    KERNEL="boot/vmlinuz-linux"
    INITRAMFS="boot/initramfs-linux.img"
else
    # Find kernel image
    KERNEL=""
    if [ -f "$OUTPUT_DIR/vmlinuz-${KERNEL_VERSION}-s390x" ]; then
        KERNEL="$OUTPUT_DIR/vmlinuz-${KERNEL_VERSION}-s390x"
    elif [ -f "$OUTPUT_DIR/bzImage" ]; then
        KERNEL="$OUTPUT_DIR/bzImage"
    else
        echo -e "${RED}Error: No kernel found. Run 'make kernel' first${NC}"
        exit 1
    fi

    # Find initramfs
    INITRAMFS=""
    for img in "$OUTPUT_DIR/initramfs-${KERNEL_VERSION}-s390x.img" \
               "$OUTPUT_DIR/initramfs-${KERNEL_VERSION}-s390x-manual.img" \
               "$OUTPUT_DIR/initramfs.img"; do
        if [ -f "$img" ]; then
            INITRAMFS="$img"
            break
        fi
    done

    if [ -z "$INITRAMFS" ]; then
        echo -e "${RED}Error: No initramfs found. Run 'make initramfs' first${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Using:${NC}"
echo "  Kernel: $KERNEL"
echo "  Initramfs: $INITRAMFS"
echo "  Memory: $QEMU_MEM"
echo "  CPU: $QEMU_CPU"

# Create script to run QEMU
cat > run-qemu-s390x.sh << EOF
#!/bin/bash
# Auto-generated QEMU run script

echo "Starting QEMU s390x emulation..."
echo "Press Ctrl-A X to exit"
echo ""

qemu-system-s390x \\
    -machine s390-ccw-virtio \\
    -cpu $QEMU_CPU \\
    -m $QEMU_MEM \\
    -kernel "$KERNEL" \\
    -initrd "$INITRAMFS" \\
    -append "root=/dev/ram0 console=ttyS0 init=/init" \\
    -nographic \\
    -device virtio-net-ccw,netdev=net0 \\
    -netdev user,id=net0 \\
    -device virtio-blk-ccw,drive=drive0 \\
    -drive file=/dev/zero,if=none,id=drive0,format=raw,readonly=on
EOF
chmod +x run-qemu-s390x.sh

# Option to run directly
echo ""
echo -e "${YELLOW}QEMU run script created: ./run-qemu-s390x.sh${NC}"
echo ""
read -p "Run QEMU now? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Starting QEMU (press Ctrl-A X to exit)...${NC}"
    ./run-qemu-s390x.sh
else
    echo -e "${GREEN}Run './run-qemu-s390x.sh' to start QEMU${NC}"
fi