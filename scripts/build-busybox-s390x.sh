#!/bin/bash
# Build s390x Busybox Binary
# This script builds a static busybox binary for s390x architecture to fix
# the architecture mismatch issue in the initramfs.

set -e

BUILD_DIR="/tmp/busybox-build"
OUTPUT_DIR="/output"
BUSYBOX_VERSION="1.35.0"

echo "Building s390x Busybox binary..."

# Install build dependencies
dnf install -y \
    gcc-s390x-linux-gnu \
    binutils-s390x-linux-gnu \
    kernel-headers \
    glibc-headers \
    glibc-devel \
    musl-devel \
    make \
    wget \
    tar

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download and extract busybox
if [ ! -f "busybox-${BUSYBOX_VERSION}.tar.bz2" ]; then
    wget "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"
fi
tar -xjf "busybox-${BUSYBOX_VERSION}.tar.bz2"
cd "busybox-${BUSYBOX_VERSION}/"

# Set cross-compilation environment
export ARCH=s390
export CROSS_COMPILE=s390x-linux-gnu-
export CC=s390x-linux-gnu-gcc
export AR=s390x-linux-gnu-ar
export STRIP=s390x-linux-gnu-strip

# Configure with minimal static build
make defconfig

# Create custom config for static linking and minimal size
cat >> .config << 'EOF'
CONFIG_STATIC=y
CONFIG_FEATURE_HAVE_RPC=n
CONFIG_SELINUX=n
CONFIG_FEATURE_SYSTEMD=n
CONFIG_PAM=n
CONFIG_FEATURE_UTMP=n
CONFIG_FEATURE_WTMP=n
CONFIG_LOCALE_SUPPORT=n
CONFIG_UNICODE_SUPPORT=n
CONFIG_FEATURE_EDITING=n
CONFIG_FEATURE_TAB_COMPLETION=n
EOF

# Disable problematic options that might use byteswap.h
sed -i 's/CONFIG_FEATURE_HAVE_RPC=y/CONFIG_FEATURE_HAVE_RPC=n/' .config
sed -i 's/CONFIG_LOCALE_SUPPORT=y/CONFIG_LOCALE_SUPPORT=n/' .config

# Create minimal byteswap.h if missing
if [ ! -f /usr/include/byteswap.h ]; then
    echo "Creating minimal byteswap.h..."
    mkdir -p include
    cat > include/byteswap.h << 'BYTESWAP_EOF'
#ifndef _BYTESWAP_H
#define _BYTESWAP_H

#include <stdint.h>

#if defined(__GNUC__)
#define bswap_16(x) __builtin_bswap16(x)
#define bswap_32(x) __builtin_bswap32(x)
#define bswap_64(x) __builtin_bswap64(x)
#else
static inline uint16_t bswap_16(uint16_t x) {
    return (x >> 8) | (x << 8);
}
static inline uint32_t bswap_32(uint32_t x) {
    return ((x >> 24) & 0xff) | ((x << 8) & 0xff0000) | 
           ((x >> 8) & 0xff00) | ((x << 24) & 0xff000000);
}
static inline uint64_t bswap_64(uint64_t x) {
    return bswap_32(x >> 32) | ((uint64_t)bswap_32(x) << 32);
}
#endif

#endif /* _BYTESWAP_H */
BYTESWAP_EOF
fi

# Build with specific flags to handle missing headers
echo "Building busybox..."
make \
    EXTRA_CFLAGS="-I$(pwd)/include -D__MUSL__ -static" \
    EXTRA_LDFLAGS="-static -pthread" \
    CONFIG_EXTRA_LDLIBS="pthread" \
    -j$(nproc) 2>&1 | tee build.log

# Verify the binary was built and is correct architecture
if [ -f busybox ]; then
    echo "Verifying busybox binary:"
    file busybox
    ls -la busybox
    
    # Copy to output directory
    cp busybox "$OUTPUT_DIR/busybox-s390x"
    chmod +x "$OUTPUT_DIR/busybox-s390x"
    
    echo "✅ s390x busybox binary built successfully!"
    echo "Size: $(du -h busybox | cut -f1)"
    echo "Architecture: $(file busybox | grep -o 'ELF.*')"
else
    echo "❌ Build failed - no busybox binary found"
    echo "Build log:"
    tail -20 build.log
    exit 1
fi
