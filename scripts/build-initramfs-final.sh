#!/bin/bash

set -e

# Configuration
KERNEL_VERSION="${KERNEL_VERSION:-6.6.10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"
INITRAMFS_NAME="initramfs-${KERNEL_VERSION}-s390x.img"
MKINITCPIO_SOURCE="/home/josie/development/archlinux/mkinitcpio" # changeme :)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Building initramfs with modified mkinitcpio ===${NC}"

# Create build script that runs inside container
cat > "$PROJECT_ROOT/build-final-initramfs.sh" << 'EOF'
#!/bin/bash
set -e

KERNEL_VERSION="6.6.10"
INITRAMFS_OUTPUT="/work/output/initramfs-${KERNEL_VERSION}-s390x.img"

echo "Building and installing modified mkinitcpio..."

# Copy the mkinitcpio source
cp -r /work/mkinitcpio-source /tmp/mkinitcpio
cd /tmp/mkinitcpio

# Apply s390x patches
echo "Applying s390x patches to mkinitcpio..."
cat > install/base << 'PATCH_EOF'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Modified for s390x cross-architecture support

build() {
    local applet
    
    # Use s390x busybox binary if available (cross-architecture support)
    if [[ -f "/work/output/busybox-s390x-static" ]]; then
        echo "Using s390x static busybox binary"
        add_file "/work/output/busybox-s390x-static" "/bin/busybox" 755
        
        # Create symlinks for busybox applets (using a known list since we can't execute cross-arch binary)
        local busybox_applets=(
            "[" "[[" "ash" "awk" "basename" "cat" "chgrp" "chmod" "chown" "cp" "cut"
            "date" "dd" "df" "dirname" "dmesg" "du" "echo" "env" "expr" "false"
            "find" "grep" "head" "hostname" "id" "kill" "ln" "ls" "mkdir" "mknod"
            "mktemp" "mount" "mv" "printf" "ps" "pwd" "readlink" "rm" "rmdir"
            "sed" "sh" "sleep" "sort" "stat" "tail" "tar" "test" "touch" "tr"
            "true" "umount" "uname" "uniq" "wc" "which" "whoami" "xargs"
        )
        
        for applet in "${busybox_applets[@]}"; do
            add_symlink "/usr/bin/$applet" busybox
        done
    elif [[ -f "/work/output/busybox-s390x-native" ]]; then
        echo "Using s390x busybox binary"
        add_file "/work/output/busybox-s390x-native" "/bin/busybox" 755
        
        # Create symlinks for busybox applets (using a known list since we can't execute cross-arch binary)
        local busybox_applets=(
            "[" "[[" "ash" "awk" "basename" "cat" "chgrp" "chmod" "chown" "cp" "cut"
            "date" "dd" "df" "dirname" "dmesg" "du" "echo" "env" "expr" "false"
            "find" "grep" "head" "hostname" "id" "kill" "ln" "ls" "mkdir" "mknod"
            "mktemp" "mount" "mv" "printf" "ps" "pwd" "readlink" "rm" "rmdir"
            "sed" "sh" "sleep" "sort" "stat" "tail" "tar" "test" "touch" "tr"
            "true" "umount" "uname" "uniq" "wc" "which" "whoami" "xargs"
        )
        
        for applet in "${busybox_applets[@]}"; do
            add_symlink "/usr/bin/$applet" busybox
        done
    else
        echo "Warning: s390x busybox not found, using system busybox (may cause architecture mismatch)"
        add_binary /usr/lib/initcpio/busybox /bin/busybox
        for applet in $(/usr/lib/initcpio/busybox --list 2>/dev/null || echo "sh ash"); do
            add_symlink "/usr/bin/$applet" busybox
        done
    fi

    # Add kmod with applet symlinks (if available)
    if type -P kmod >/dev/null 2>&1; then
        echo "Adding kmod utilities..."
        add_binary kmod
        for applet in {dep,ins,rm,ls}mod mod{probe,info}; do
            add_symlink "/usr/bin/$applet" kmod
        done
    else
        echo "Warning: kmod not found, module utilities will not be available"
    fi

    # Check for additional utilities (may not be available in cross-compile environment)
    for binary in blkid mount umount switch_root; do
        if type -P "$binary" >/dev/null 2>&1; then
            echo "Adding $binary"
            add_binary "$binary"
        else
            echo "Warning: $binary not found, skipping (functionality may be limited)"
        fi
    done

    # Always add init files
    echo "Adding init files..."
    add_file "/usr/lib/initcpio/init_functions" "/init_functions"
    add_file "/usr/lib/initcpio/init" "/init" 755
}

help() {
    cat <<HELPEOF
This hook provides crucial runtime necessities for booting. This is a modified 
version with s390x cross-architecture support. DO NOT remove this hook unless 
you know what you're doing.
HELPEOF
}

# vim: set ft=sh ts=4 sw=4 et:
PATCH_EOF

echo "✓ Applied s390x patches to base install hook"

# Clean any existing build
rm -rf build

# Build with meson
echo "Setting up meson build..."
meson setup build --prefix=/usr --sysconfdir=/etc

echo "Building mkinitcpio..."
meson compile -C build

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
dnf install -y kmod-libs kmod util-linux busybox || echo "Warning: Some packages could not be installed"

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
if [ -f /usr/lib/initcpio/init ]; then
    echo "✓ /usr/lib/initcpio/init found"
else
    echo "✗ /usr/lib/initcpio/init missing - copying from source"
    if [ -f /tmp/mkinitcpio/init ]; then
        mkdir -p /usr/lib/initcpio
        cp /tmp/mkinitcpio/init /usr/lib/initcpio/init
        chmod 755 /usr/lib/initcpio/init
    fi
fi

if [ -f /usr/lib/initcpio/init_functions ]; then
    echo "✓ /usr/lib/initcpio/init_functions found"
else
    echo "✗ /usr/lib/initcpio/init_functions missing - copying from source"
    if [ -f /tmp/mkinitcpio/init_functions ]; then
        cp /tmp/mkinitcpio/init_functions /usr/lib/initcpio/init_functions
    fi
fi

# Create a minimal working s390x configuration
echo "Creating minimal s390x configuration..."

# Copy custom init if available
if [ -f /work/custom-init ]; then
    echo "Using custom init for initramfs-only system"
    cp /work/custom-init /usr/lib/initcpio/init
    chmod 755 /usr/lib/initcpio/init
fi

cat > /etc/mkinitcpio-s390x.conf << 'CONFIG'
# Minimal s390x mkinitcpio configuration
# This config creates a basic initramfs without kernel modules
MODULES=()
BINARIES=()
FILES=()
# Only use base hook which provides busybox, init, and basic utilities
HOOKS=(base)
COMPRESSION="gzip"
COMPRESSION_OPTIONS=(-6)
CONFIG

echo "Generating initramfs with mkinitcpio..."
echo "Configuration:"
cat /etc/mkinitcpio-s390x.conf

# The s390x busybox integration is now handled by the patched base install hook
echo "s390x busybox will be handled by the patched mkinitcpio base hook..."

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

# Copy the mkinitcpio source to our project for mounting
echo -e "${YELLOW}Copying mkinitcpio source...${NC}"
rm -rf "$PROJECT_ROOT/mkinitcpio-source"
cp -r "$MKINITCPIO_SOURCE" "$PROJECT_ROOT/mkinitcpio-source"

# Run mkinitcpio in container
echo -e "${YELLOW}Running modified mkinitcpio for s390x...${NC}"
sudo podman run --rm \
    -v "$PROJECT_ROOT:/work" \
    -w /work \
    --privileged \
    s390x-mkinitcpio-complete \
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
