# Arch Linux s390x Build Environment
# Fedora 39 with s390x cross-compilation tools and mkinitcpio support
FROM fedora:39

# Install complete cross-compilation environment for kernel builds and mkinitcpio
RUN dnf install -y \
    # Core cross-compilation tools
    gcc-s390x-linux-gnu \
    binutils-s390x-linux-gnu \
    kernel-cross-headers \
    glibc-devel \
    glibc-headers \
    glibc-static \
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
    && dnf clean all

# Upgrade meson to latest version (Fedora 39 has 1.3.2, mkinitcpio needs >=1.4.0)
RUN pip3 install --upgrade meson

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
LABEL description="Fedora 39 with s390x cross-compilation tools and mkinitcpio support for Arch Linux s390x port"
LABEL version="1.0"
LABEL architecture="s390x-cross"