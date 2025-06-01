#!/bin/bash

set -e

# Configuration
KERNEL_VERSION="${KERNEL_VERSION:-6.6.10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"
INITRAMFS_NAME="initramfs-${KERNEL_VERSION}-s390x.img"
MKINITCPIO_SOURCE="$PROJECT_ROOT/mkinitcpio-source"
MKINITCPIO_REPO="https://github.com/archlinux/mkinitcpio.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Building initramfs with modified mkinitcpio ===${NC}"

# Clone mkinitcpio from upstream (latest version)
echo -e "${YELLOW}Cloning mkinitcpio from upstream (latest)...${NC}"
rm -rf "$MKINITCPIO_SOURCE"
git clone --depth 1 "$MKINITCPIO_REPO" "$MKINITCPIO_SOURCE"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to clone mkinitcpio${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cloned latest mkinitcpio${NC}"

# Create build script that runs inside container
cat > "$PROJECT_ROOT/build-final-initramfs.sh" << 'EOF'
#!/bin/bash
set -e

KERNEL_VERSION="6.6.10"
INITRAMFS_OUTPUT="/work/output/initramfs-${KERNEL_VERSION}-s390x.img"

echo "Building and installing modified mkinitcpio..."

# Copy the mkinitcpio source
mkdir -p /tmp/mkinitcpio
cp -r /work/mkinitcpio-source/* /tmp/mkinitcpio/
cp -r /work/mkinitcpio-source/.[^.]* /tmp/mkinitcpio/ 2>/dev/null || true
cd /tmp/mkinitcpio

# Verify we're in the right directory
if [ ! -f "meson.build" ]; then
    echo "ERROR: meson.build not found. Directory contents:"
    ls -la
    exit 1
fi

# Apply s390x patches
echo "Applying s390x patches to mkinitcpio..."

# Check if patch file exists and apply it
if [ -f "/work/patches/mkinitcpio-s390x-base-hook.patch" ]; then
    echo "Found mkinitcpio patch, applying..."
    cp /work/patches/mkinitcpio-s390x-base-hook.patch install/base
    chmod +x install/base
    echo "✓ Applied s390x patches to base install hook"
else
    echo "ERROR: Patch file not found at /work/patches/mkinitcpio-s390x-base-hook.patch"
    exit 1
fi

# Clean any existing build directory
rm -rf build

# Build with meson
echo "Setting up meson build..."
meson setup build --prefix=/usr --sysconfdir=/etc

echo "Installing mkinitcpio..."
meson install -C build

# Check where files were installed
echo "Checking mkinitcpio installation..."
find /usr -name "init_functions" -o -name "init" | grep initcpio || true
ls -la /usr/lib/initcpio/ 2>/dev/null || true
ls -la /usr/lib64/initcpio/ 2>/dev/null || true

echo "Setting up s390x environment..."

# Install missing dependencies
echo "Installing required dependencies..."
dnf install -y kmod-libs kmod util-linux busybox bsdtar || echo "Warning: Some packages could not be installed"

# Create kernel module directory structure
KERNEL_DIR="/lib/modules/${KERNEL_VERSION}-s390x"
mkdir -p "$KERNEL_DIR"

# Create minimal modules.dep files to satisfy mkinitcpio
touch "$KERNEL_DIR/modules.dep"
touch "$KERNEL_DIR/modules.dep.bin"
touch "$KERNEL_DIR/modules.alias"
touch "$KERNEL_DIR/modules.alias.bin"

# Copy kernel if it exists
if [ -f "/work/output/vmlinuz-${KERNEL_VERSION}-s390x" ]; then
    cp "/work/output/vmlinuz-${KERNEL_VERSION}-s390x" "/boot/vmlinuz-${KERNEL_VERSION}-s390x"
    echo "Kernel copied to /boot/"
fi

# Ensure init files are in the correct location
echo "Verifying init files installation..."
# Check both lib and lib64 locations
if [ -f /usr/lib/initcpio/init ] || [ -f /usr/lib64/initcpio/init ]; then
    echo "✓ init found"
else
    echo "✗ init missing - copying from source"
    if [ -f /tmp/mkinitcpio/init ]; then
        mkdir -p /usr/lib/initcpio
        cp /tmp/mkinitcpio/init /usr/lib/initcpio/init
        chmod 755 /usr/lib/initcpio/init
    fi
fi

if [ -f /usr/lib/initcpio/init_functions ] || [ -f /usr/lib64/initcpio/init_functions ]; then
    echo "✓ init_functions found"
else
    echo "✗ init_functions missing - copying from source"
    if [ -f /tmp/mkinitcpio/init_functions ]; then
        mkdir -p /usr/lib/initcpio
        cp /tmp/mkinitcpio/init_functions /usr/lib/initcpio/init_functions
    fi
fi

# Create symlinks if installed in lib64
if [ -d /usr/lib64/initcpio ] && [ ! -d /usr/lib/initcpio ]; then
    echo "Creating symlinks from lib64 to lib..."
    mkdir -p /usr/lib
    ln -sf /usr/lib64/initcpio /usr/lib/initcpio
fi

# Create a minimal working s390x configuration
echo "Creating minimal s390x configuration..."

# Copy custom init if available
if [ -f /work/custom-init ]; then
    echo "Using custom init for initramfs-only system"
    cp /work/custom-init /usr/lib/initcpio/init
    chmod 755 /usr/lib/initcpio/init
fi

# Copy mkinitcpio configuration
if [ -f "/work/patches/mkinitcpio-s390x.conf" ]; then
    echo "Using s390x mkinitcpio configuration..."
    cp /work/patches/mkinitcpio-s390x.conf /etc/mkinitcpio-s390x.conf
else
    echo "ERROR: Configuration file not found at /work/patches/mkinitcpio-s390x.conf"
    exit 1
fi

echo "Generating initramfs with mkinitcpio..."
echo "Configuration:"
cat /etc/mkinitcpio-s390x.conf

# The s390x busybox integration is now handled by the patched base install hook
echo "s390x busybox will be handled by the patched mkinitcpio base hook..."

# Ensure busybox binary is available for the base hook
if [ -f "/work/output/busybox-s390x-static" ]; then
    echo "✓ Found s390x static busybox at /work/output/busybox-s390x-static"
    ls -la /work/output/busybox-s390x-static
elif [ -f "/work/output/busybox-s390x-native" ]; then
    echo "✓ Found s390x native busybox at /work/output/busybox-s390x-native"
    ls -la /work/output/busybox-s390x-native
else
    echo "ERROR: No s390x busybox binary found in /work/output/"
    echo "Available files in /work/output:"
    ls -la /work/output/
    exit 1
fi

# Debug: List all files that mkinitcpio expects
echo "Checking mkinitcpio dependencies:"
ls -la /usr/lib/initcpio/ 2>/dev/null || echo "/usr/lib/initcpio/ not found"

# Generate the initramfs with verbose output
echo "Running mkinitcpio..."
/usr/bin/mkinitcpio -c /etc/mkinitcpio-s390x.conf \
                    -g "$INITRAMFS_OUTPUT" \
                    -k "${KERNEL_VERSION}-s390x" \
                    -v 2>&1 | tee /tmp/mkinitcpio.log

echo "mkinitcpio generation completed!"
if [ -f "$INITRAMFS_OUTPUT" ]; then
    ls -la "$INITRAMFS_OUTPUT"
    echo "Initramfs size: $(du -h "$INITRAMFS_OUTPUT" | cut -f1)"
    
    # Analyze the generated initramfs
    echo ""
    echo "Analyzing generated initramfs..."
    echo "Checking for critical files:"
    
    # Extract and check for init
    mkdir -p /tmp/initramfs-check
    cd /tmp/initramfs-check
    zcat "$INITRAMFS_OUTPUT" | cpio -id 2>/dev/null
    
    if [ -f init ]; then
        echo "✓ /init found"
        ls -la init
    else
        echo "✗ /init missing!"
    fi
    
    if [ -f init_functions ]; then
        echo "✓ /init_functions found"
    else
        echo "✗ /init_functions missing!"
    fi
    
    # Check for busybox and verify architecture
    if [ -f bin/busybox ]; then
        echo "✓ busybox found at /bin/busybox"
        file bin/busybox | grep -q "s390" && echo "✓ Verified s390x architecture in initramfs" || echo "⚠ Architecture may be incorrect"
    elif [ -f usr/bin/busybox ]; then
        echo "✓ busybox found at /usr/bin/busybox" 
        file usr/bin/busybox | grep -q "s390" && echo "✓ Verified s390x architecture in initramfs" || echo "⚠ Architecture may be incorrect"
    else
        echo "✗ busybox missing from initramfs!"
    fi
    
    # List first 20 files
    echo ""
    echo "First 20 files in initramfs:"
    find . -type f | head -20
    
    # Cleanup
    cd /
    rm -rf /tmp/initramfs-check
    
    echo ""
    echo "✓ Success!"
else
    echo "✗ Failed to generate initramfs"
    exit 1
fi
EOF

chmod +x "$PROJECT_ROOT/build-final-initramfs.sh"

# mkinitcpio source already cloned at the beginning of the script

# Run mkinitcpio in container
echo -e "${YELLOW}Running modified mkinitcpio for s390x...${NC}"
sudo podman run --rm \
    -v "$PROJECT_ROOT:/work" \
    -w /work \
    --privileged \
    s390x-archlinux-dev \
    /work/build-final-initramfs.sh

# Clean up copied source
rm -rf "$PROJECT_ROOT/mkinitcpio-source"

# Check result
if [ -f "$OUTPUT_DIR/$INITRAMFS_NAME" ]; then
    SIZE=$(du -h "$OUTPUT_DIR/$INITRAMFS_NAME" | cut -f1)
    echo -e "${GREEN}✓ Initramfs created with modified mkinitcpio: $OUTPUT_DIR/$INITRAMFS_NAME (${SIZE})${NC}"
    
    # Update todo to completed
    echo -e "${YELLOW}Marking initramfs build as completed...${NC}"
else
    echo -e "${RED}✗ Failed to create initramfs with modified mkinitcpio${NC}"
    exit 1
fi
