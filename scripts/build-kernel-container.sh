#!/bin/bash
# Build kernel inside the Fedora container 

set -e

# Configuration
KERNEL_VERSION="${KERNEL_VERSION:-6.6.10}"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build-kernel"
OUTPUT_DIR="$PROJECT_ROOT/output"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Building kernel ${KERNEL_VERSION} for s390x ===${NC}"
echo -e "${YELLOW}This will run the entire build inside a container with a single sudo prompt${NC}"

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Download kernel 
if [ ! -f "$BUILD_DIR/linux-${KERNEL_VERSION}.tar.xz" ]; then
    echo -e "${YELLOW}Downloading kernel ${KERNEL_VERSION}...${NC}"
    wget -P "$BUILD_DIR" "$KERNEL_URL"
fi

# Extract kernel
if [ ! -d "$BUILD_DIR/linux-${KERNEL_VERSION}" ]; then
    echo -e "${YELLOW}Extracting kernel source...${NC}"
    tar -xf "$BUILD_DIR/linux-${KERNEL_VERSION}.tar.xz" -C "$BUILD_DIR"
fi

# Create build script 
cat > "$BUILD_DIR/build-in-container.sh" << 'EOF'
#!/bin/bash
set -e

KERNEL_VERSION="$1"
cd "/work/build-kernel/linux-${KERNEL_VERSION}"

# Setup environment
export ARCH=s390
export CROSS_COMPILE=s390x-linux-gnu-

echo "Generating s390x config..."
make defconfig

# Apply s390x specific config
cat >> .config << 'EOFCONFIG'

# Essential s390x configuration
CONFIG_S390=y
CONFIG_64BIT=y
CONFIG_MARCH_Z13=y

# Storage drivers
CONFIG_DASD=y
CONFIG_DASD_ECKD=y
CONFIG_DASD_FBA=y
CONFIG_DASD_DIAG=y

# Network drivers
CONFIG_QETH=y
CONFIG_QETH_L2=y
CONFIG_QETH_L3=y
CONFIG_QETH_OSX=y

# Virtualization support
CONFIG_VIRTIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_PCI=y

# Console support
CONFIG_TN3215=y
CONFIG_TN3270=y

# System identity
CONFIG_DEFAULT_HOSTNAME="arch"

# Required for initramfs
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_RD_BZIP2=y
CONFIG_RD_XZ=y

# Disable module signing to avoid certificate issues
CONFIG_MODULE_SIG=n
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_KEY=""
EOFCONFIG

# Update config
make olddefconfig

echo "Building kernel..."
make -j$(nproc) bzImage

# Skip module installation for now to avoid signing issues
echo "Skipping module installation..."

# Copy output files
cp arch/s390/boot/bzImage "/work/output/vmlinuz-${KERNEL_VERSION}-s390x"
cp System.map "/work/output/System.map-${KERNEL_VERSION}-s390x"
cp .config "/work/output/config-${KERNEL_VERSION}-s390x"

echo "Kernel build complete!"
EOF

chmod +x "$BUILD_DIR/build-in-container.sh"

# Run the build in container with single sudo
echo -e "${YELLOW}Running build in container (requires sudo)...${NC}"
sudo podman run --rm \
    -v "$PROJECT_ROOT:/work" \
    -w /work \
    -e KERNEL_VERSION="$KERNEL_VERSION" \
    s390x-archlinux-dev \
    /work/build-kernel/build-in-container.sh "$KERNEL_VERSION"

# Create kernel info file
cat > "$OUTPUT_DIR/kernel-info.txt" << EOF
Kernel Version: ${KERNEL_VERSION}
Architecture: s390x
Build Date: $(date)
Build Method: Fedora container
EOF

echo -e "${GREEN}✓ Kernel build complete!${NC}"
echo -e "${GREEN}Output files in: $OUTPUT_DIR/${NC}"
ls -la "$OUTPUT_DIR/"
