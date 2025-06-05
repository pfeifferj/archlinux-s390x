#!/bin/bash
# Build static busybox on z/VM s390x RHEL system
# SPDX-License-Identifier: GPL-2.0-only

# Source utilities (only common.sh since this runs on z/VM)
if [ -f "scripts/common.sh" ]; then
    source scripts/common.sh
else
    # Minimal logging for z/VM environment
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    die() { log_error "$1"; exit "${2:-1}"; }
fi

log_info "Building static busybox on native s390x..."

# Install build dependencies
sudo dnf install -y gcc make wget tar bzip2 glibc-static

# Extract busybox
tar -xjf busybox-1.35.0.tar.bz2
cd busybox-1.35.0

# Configure for static build
make defconfig

# Enable static linking in config
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
EOF

# Disable problematic options
sed -i 's/CONFIG_FEATURE_HAVE_RPC=y/CONFIG_FEATURE_HAVE_RPC=n/' .config
sed -i 's/CONFIG_LOCALE_SUPPORT=y/CONFIG_LOCALE_SUPPORT=n/' .config

# Build static busybox
echo "Building with static linking..."
make CONFIG_STATIC=y LDFLAGS="-static" -j$(nproc)

# Verify the binary
if [ -f busybox ]; then
    echo "✅ Busybox built successfully!"
    echo "File info:"
    file busybox
    echo "Size: $(du -h busybox | cut -f1)"
    echo "Static linking check:"
    ldd busybox 2>&1 | head -1
    
    # Copy to home directory for easy transfer
    cp busybox ~/busybox-s390x-static
    chmod +x ~/busybox-s390x-static
    echo "✅ Copied to ~/busybox-s390x-static"
else
    echo "❌ Build failed!"
    exit 1
fi