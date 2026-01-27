# Arch Linux s390x Build Environment
# Stage 1: Base system with package manager cache
FROM fedora:43 AS base-system
RUN sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/fedora-updates-testing.repo

# Stage 2: Cross-compilation tools
FROM base-system AS cross-tools
RUN dnf install -y --setopt=install_weak_deps=False \
    # Core cross-compilation tools
    gcc-s390x-linux-gnu \
    binutils-s390x-linux-gnu \
    kernel-cross-headers \
    kernel-headers \
    glibc-devel \
    glibc-headers \
    glibc-static \
    libstdc++-devel \
    libstdc++-static \
    && dnf clean all

# Stage 3: Build dependencies
FROM cross-tools AS build-deps
RUN dnf install -y --setopt=install_weak_deps=False \
    # Kernel build dependencies
    make \
    flex \
    bison \
    bc \
    openssl \
    openssl-devel \
    elfutils-libelf-devel \
    perl \
    ncurses-devel \
    diffutils \
    findutils \
    kmod \
    # General utilities
    git \
    tar \
    xz \
    wget \
    bzip2 \
    cpio \
    gzip \
    rsync \
    bash \
    coreutils \
    util-linux \
    file \
    busybox \
    bsdtar \
    && dnf clean all

# Stage 4: mkinitcpio dependencies
FROM build-deps AS mkinitcpio-deps
RUN dnf install -y --setopt=install_weak_deps=False \
    # mkinitcpio build dependencies
    python3 \
    python3-pip \
    ninja-build \
    asciidoc \
    xmlto \
    docbook-style-xsl \
    libxslt \
    pkgconfig \
    systemd-devel \
    systemd-libs \
    systemd \
    systemd-udev \
    && dnf clean all

# Upgrade meson to latest version (mkinitcpio needs >=1.4.0)
RUN pip3 install --upgrade --no-cache-dir meson

# Verify systemd pkg-config files are available
RUN pkg-config --exists systemd && echo "✓ systemd pkg-config found" || echo "✗ systemd pkg-config missing"
RUN pkg-config --modversion systemd || echo "✗ systemd version check failed"

# Stage 5: Final image
FROM mkinitcpio-deps AS final

# Add remaining language packs and optional dependencies
RUN dnf install -y --setopt=install_weak_deps=False \
    glibc-common \
    glibc-all-langpacks \
    musl-devel \
    musl-gcc \
    musl-libc-static \
    && dnf clean all

# Verify meson version
RUN meson --version

# Create symlinks for cross-compilation headers
RUN ln -sf /usr/s390-linux-gnu/include /usr/s390x-linux-gnu/sys-include

# Create directories for kernel and modules
RUN mkdir -p /lib/modules /boot /etc

# Set up environment for s390x cross-compilation
ENV ARCH=s390
ENV CROSS_COMPILE=s390x-linux-gnu-

WORKDIR /work

# Label the image
LABEL description="Fedora 43 with s390x cross-compilation tools and mkinitcpio support for Arch Linux s390x port"
LABEL version="1.1"
LABEL architecture="s390x-cross"