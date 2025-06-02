#!/bin/bash
# Build static busybox on z/VM s390x RHEL system

set -e

echo "Building static busybox on native s390x..."

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