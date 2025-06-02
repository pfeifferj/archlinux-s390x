#!/bin/bash
# Build minimal systemd natively on z/VM RHEL 9.6
# This script should be run on the z/VM system via SSH

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SYSTEMD_VERSION="256.7"
BUILD_DIR="$HOME/systemd-build"
OUTPUT_DIR="$HOME/systemd-minimal"
PREFIX="/usr"

echo -e "${GREEN}=== Building minimal systemd on s390x z/VM ===${NC}"
echo "This will build systemd natively on RHEL 9.6 s390x"

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Install build dependencies if not already present
echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo dnf install -y \
    gcc \
    gcc-c++ \
    meson \
    ninja-build \
    pkgconfig \
    gperf \
    glib2-devel \
    libcap-devel \
    libmount-devel \
    libblkid-devel \
    libuuid-devel \
    libseccomp-devel \
    libacl-devel \
    libattr-devel \
    kmod-devel \
    elfutils-devel \
    dbus-devel \
    python3-jinja2 \
    wget \
    tar \
    gzip

# Download systemd
cd "$BUILD_DIR"
if [ ! -d "systemd-$SYSTEMD_VERSION" ]; then
    echo -e "${YELLOW}Downloading systemd $SYSTEMD_VERSION...${NC}"
    wget -q "https://github.com/systemd/systemd/archive/v$SYSTEMD_VERSION.tar.gz"
    tar xzf "v$SYSTEMD_VERSION.tar.gz"
fi

cd "systemd-$SYSTEMD_VERSION"

# Configure minimal build for s390x
echo -e "${YELLOW}Configuring minimal systemd build...${NC}"
meson setup build-minimal \
    --prefix="$PREFIX" \
    --sysconfdir=/etc \
    --localstatedir=/var \
    -Drootprefix=/usr \
    -Drootlibdir=/lib \
    -Dmode=release \
    -Dlink-udev-shared=true \
    -Dsplit-bin=false \
    -Dsplit-usr=false \
    -Dresolve=false \
    -Dnetworkd=false \
    -Dlogind=false \
    -Dmachined=false \
    -Dhomed=false \
    -Dportabled=false \
    -Duserdb=false \
    -Dbootloader=false \
    -Defi=false \
    -Dlibcryptsetup=false \
    -Dlibiptc=false \
    -Dlibidn2=false \
    -Dlibcurl=false \
    -Dlibidn=false \
    -Dlz4=false \
    -Dxz=false \
    -Dzlib=false \
    -Dbzip2=false \
    -Dzstd=false \
    -Dgcrypt=false \
    -Dopenssl=false \
    -Dp11kit=false \
    -Dbinfmt=false \
    -Dcoredump=false \
    -Dpolkit=false \
    -Dman=false \
    -Dhtml=false \
    -Dtests=false \
    -Dinstall-tests=false \
    -Dnss-myhostname=false \
    -Dnss-mymachines=false \
    -Dnss-resolve=false \
    -Dnss-systemd=false \
    -Dpam=false \
    -Dselinux=false \
    -Dapparmor=false \
    -Daudit=false \
    -Dima=false \
    -Dsmack=false \
    -Dseccomp=true \
    -Dxkbcommon=false \
    -Dpcre2=false \
    -Dglib=false \
    -Ddbus=true \
    -Dgnutls=false \
    -Dmicrohttpd=false \
    -Dlibfido2=false \
    -Dtpm=false \
    -Dtpm2=false \
    -Dqrencode=false \
    -Db_lto=false \
    -Db_pie=true

# Build
echo -e "${YELLOW}Building systemd...${NC}"
ninja -C build-minimal

# Install to output directory
echo -e "${YELLOW}Installing to $OUTPUT_DIR...${NC}"
DESTDIR="$OUTPUT_DIR" ninja -C build-minimal install

# Strip binaries
echo -e "${YELLOW}Stripping binaries...${NC}"
find "$OUTPUT_DIR" -type f -executable -exec file {} \; | \
    grep 'ELF.*executable' | cut -d: -f1 | \
    xargs -r strip --strip-unneeded

# Remove non-essential files
echo -e "${YELLOW}Removing non-essential files...${NC}"
rm -rf "$OUTPUT_DIR/usr/share/doc"
rm -rf "$OUTPUT_DIR/usr/share/man"
rm -rf "$OUTPUT_DIR/usr/share/locale"
rm -rf "$OUTPUT_DIR/usr/share/factory"
rm -rf "$OUTPUT_DIR/usr/share/bash-completion"
rm -rf "$OUTPUT_DIR/usr/share/zsh"

# Keep only essential binaries
cd "$OUTPUT_DIR/usr/bin"
for binary in *; do
    case "$binary" in
        systemctl|journalctl|systemd-*) ;;
        *) rm -f "$binary" ;;
    esac
done

# Copy essential system libraries for runtime
echo -e "${YELLOW}Copying runtime libraries...${NC}"
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/lib64"

# Copy dynamic linker and essential libraries
cp -L /lib64/ld-linux-s390x.so.2 "$OUTPUT_DIR/lib/" 2>/dev/null || true
cp -L /lib64/ld64.so.1 "$OUTPUT_DIR/lib/" 2>/dev/null || true

# Copy essential glibc and other system libraries
for lib in libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 \
           libcrypt.so.1 libcap.so.2 libblkid.so.1 libuuid.so.1 \
           libmount.so.1 libseccomp.so.2 libacl.so.1 libattr.so.1 \
           libkmod.so.2 libdw.so.1 libelf.so.1 libz.so.1 \
           libbz2.so.1 liblzma.so.5 libdbus-1.so.3; do
    find /lib64 /usr/lib64 -name "$lib*" -exec cp -L {} "$OUTPUT_DIR/lib64/" \; 2>/dev/null || true
done

# Create lib64 symlink
ln -sf lib "$OUTPUT_DIR/lib64" 2>/dev/null || true

# Create tarball for transfer
cd "$OUTPUT_DIR"
echo -e "${YELLOW}Creating tarball...${NC}"
tar czf "$HOME/systemd-minimal-s390x.tar.gz" .

# Calculate sizes
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
TARBALL_SIZE=$(du -sh "$HOME/systemd-minimal-s390x.tar.gz" | cut -f1)

echo -e "${GREEN}✓ Minimal systemd built successfully!${NC}"
echo -e "${GREEN}Total size: $TOTAL_SIZE${NC}"
echo -e "${GREEN}Tarball size: $TARBALL_SIZE${NC}"
echo -e "${GREEN}Tarball location: $HOME/systemd-minimal-s390x.tar.gz${NC}"
echo ""
echo "To transfer back to your local system:"
echo "scp -i zvm.pem linux1@148.100.77.9:~/systemd-minimal-s390x.tar.gz output/"