#!/bin/bash
# Build Arch Linux kernel for s390x using PKGBUILD system

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARCH_KERNEL_DIR="$PROJECT_ROOT/arch-kernel"
BUILD_DIR="$PROJECT_ROOT/build-kernel"
OUTPUT_DIR="$PROJECT_ROOT/output"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Building Arch Linux kernel for s390x ===${NC}"

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Check if we have the PKGBUILD
if [ ! -f "$ARCH_KERNEL_DIR/PKGBUILD-s390x" ]; then
    echo -e "${RED}Error: PKGBUILD-s390x not found!${NC}"
    echo "Please run from the project root directory"
    exit 1
fi

# Create build environment inside container
cat > "$BUILD_DIR/build-arch-kernel-container.sh" << 'EOF'
#!/bin/bash
set -e

# Setup colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Install required build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
dnf install -y \
    bc \
    bison \
    cpio \
    flex \
    gettext \
    elfutils-libelf-devel \
    openssl-devel \
    perl \
    python3 \
    rsync \
    tar \
    xz \
    zstd \
    gcc-s390x-linux-gnu \
    binutils-s390x-linux-gnu \
    wget \
    patch \
    diffutils \
    make || {
    echo -e "${RED}Failed to install dependencies${NC}"
    exit 1
}

# Setup build directory
cd /work/arch-kernel
BUILD_DIR="/tmp/makepkg"
mkdir -p "$BUILD_DIR"

# Copy PKGBUILD and config
cp PKGBUILD-s390x "$BUILD_DIR/PKGBUILD"
cp config-s390x "$BUILD_DIR/"

cd "$BUILD_DIR"

# Download sources
echo -e "${YELLOW}Downloading kernel sources...${NC}"
KERNEL_VERSION="6.6.10"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget --no-verbose --show-progress "$KERNEL_URL" || {
        echo -e "${RED}Failed to download kernel${NC}"
        exit 1
    }
fi

# Extract and prepare sources
echo -e "${YELLOW}Extracting kernel source...${NC}"
if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
fi

# Setup cross-compilation environment
export ARCH=s390
export CROSS_COMPILE=s390x-linux-gnu-

# Enter kernel directory
cd "linux-${KERNEL_VERSION}"

# Apply s390x config
echo -e "${YELLOW}Configuring kernel for s390x...${NC}"
cp ../config-s390x .config
make olddefconfig

# Show kernel version
echo -e "${GREEN}Building kernel version: $(make -s kernelrelease)${NC}"

# Build kernel
echo -e "${YELLOW}Building kernel (this will take a while)...${NC}"
make -j$(nproc) bzImage || {
    echo -e "${RED}Kernel build failed${NC}"
    exit 1
}

# Build modules (optional, can be slow)
echo -e "${YELLOW}Building kernel modules...${NC}"
make -j$(nproc) modules || {
    echo -e "${YELLOW}Warning: Module build failed, continuing without modules${NC}"
}

# Copy kernel image
echo -e "${YELLOW}Copying output files...${NC}"
cp -v arch/s390/boot/bzImage "/work/output/vmlinuz-${KERNEL_VERSION}-s390x-arch"
cp -v System.map "/work/output/System.map-${KERNEL_VERSION}-s390x-arch"
cp -v .config "/work/output/config-${KERNEL_VERSION}-s390x-arch"

# Create kernel info file
cat > /work/output/kernel-info-arch.txt << EOFINFO
Kernel Version: ${KERNEL_VERSION}-s390x-arch
Architecture: s390x
Build Date: $(date)
Build Method: Arch Linux kernel configuration for s390x
Kernel Config: Based on Arch Linux defaults + s390x hardware support
EOFINFO

echo -e "${GREEN}✓ Arch Linux kernel build complete!${NC}"
EOF

chmod +x "$BUILD_DIR/build-arch-kernel-container.sh"

# Run the build in container
echo -e "${YELLOW}Running build in container (requires sudo)...${NC}"
sudo podman run --rm \
    -v "$PROJECT_ROOT:/work" \
    -w /work \
    s390x-archlinux-dev \
    /work/build-kernel/build-arch-kernel-container.sh

echo -e "${GREEN}✓ Arch Linux kernel for s390x built successfully!${NC}"
echo -e "${GREEN}Output files:${NC}"
ls -la "$OUTPUT_DIR/"*-arch* 2>/dev/null || echo "No Arch kernel files found yet"