#!/bin/bash
# Root filesystem creation utilities for Arch Linux s390x
# SPDX-License-Identifier: GPL-2.0-only

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Root filesystem configuration
export DEFAULT_ROOTFS_SIZE="150"
export DEFAULT_ROOTFS_NAME="rootfs-s390x.img"
export ROOTFS_MOUNT_POINT="/tmp/rootfs-mount"

# Create basic root filesystem structure
create_rootfs_structure() {
    local mount_point="$1"
    
    log_info "Creating root filesystem directory structure..."
    
    # Create standard Linux directory structure
    local dirs=(
        "bin" "sbin" "etc" "proc" "sys" "dev" "tmp" "var" "usr/bin" "usr/sbin"
        "lib" "lib64" "run" "boot" "home" "root" "opt" "srv" "mnt" "media"
        "etc/systemd/system" "var/log" "var/log/journal" "var/tmp"
        "usr/lib" "usr/lib64" "usr/share" "usr/include" "usr/src"
    )
    
    for dir in "${dirs[@]}"; do
        sudo mkdir -p "$mount_point/$dir"
        log_debug "Created directory: $dir"
    done
    
    log_success "Directory structure created"
}

# Create essential device nodes
create_device_nodes() {
    local mount_point="$1"
    
    log_info "Creating essential device nodes..."
    
    # Console and TTY devices
    sudo mknod "$mount_point/dev/console" c 5 1 2>/dev/null || true
    sudo mknod "$mount_point/dev/tty" c 5 0 2>/dev/null || true
    
    # TTY devices for virtual terminals
    for i in {1..4}; do
        sudo mknod "$mount_point/dev/tty$i" c 4 $i 2>/dev/null || true
    done
    
    # Null and zero devices
    sudo mknod "$mount_point/dev/null" c 1 3 2>/dev/null || true
    sudo mknod "$mount_point/dev/zero" c 1 5 2>/dev/null || true
    sudo mknod "$mount_point/dev/random" c 1 8 2>/dev/null || true
    sudo mknod "$mount_point/dev/urandom" c 1 9 2>/dev/null || true
    
    log_success "Device nodes created"
}

# Create basic system files
create_system_files() {
    local mount_point="$1"
    
    log_info "Creating basic system files..."
    
    # /etc/passwd
    sudo tee "$mount_point/etc/passwd" > /dev/null << 'EOF'
root:x:0:0:root:/root:/bin/sh
bin:x:1:1:bin:/bin:/usr/bin/nologin
daemon:x:2:2:daemon:/:/usr/bin/nologin
nobody:x:65534:65534:Kernel Overflow User:/:/usr/bin/nologin
EOF

    # /etc/group
    sudo tee "$mount_point/etc/group" > /dev/null << 'EOF'
root:x:0:
bin:x:1:
daemon:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
dip:x:30:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
EOF

    # /etc/shadow
    sudo tee "$mount_point/etc/shadow" > /dev/null << 'EOF'
root::19797:0:99999:7:::
bin:*:19797:0:99999:7:::
daemon:*:19797:0:99999:7:::
nobody:*:19797:0:99999:7:::
EOF

    # /etc/os-release (Arch Linux identification)
    sudo tee "$mount_point/etc/os-release" > /dev/null << 'EOF'
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://bugs.archlinux.org/"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=archlinux-logo
EOF

    # /etc/arch-release
    sudo tee "$mount_point/etc/arch-release" > /dev/null << 'EOF'
Arch Linux \r (\l)
EOF

    # /etc/hostname
    sudo tee "$mount_point/etc/hostname" > /dev/null << 'EOF'
archlinux-s390x
EOF

    # /etc/hosts
    sudo tee "$mount_point/etc/hosts" > /dev/null << 'EOF'
127.0.0.1	localhost
::1		localhost
127.0.1.1	archlinux-s390x.localdomain	archlinux-s390x
EOF

    # /etc/fstab
    sudo tee "$mount_point/etc/fstab" > /dev/null << 'EOF'
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
/dev/vda / ext4 rw,relatime 0 1
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devtmpfs /dev devtmpfs defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF

    log_success "System files created"
}

# Install busybox with applets
install_busybox() {
    local mount_point="$1"
    local busybox_binary="${2:-boot/busybox-s390x-static}"
    
    log_info "Installing busybox..."
    
    if [ ! -f "$busybox_binary" ]; then
        log_error "Busybox binary not found: $busybox_binary"
        return 1
    fi
    
    # Copy busybox binary
    sudo cp "$busybox_binary" "$mount_point/bin/busybox"
    sudo chmod +x "$mount_point/bin/busybox"
    
    # Install busybox applets
    log_info "Installing busybox applets..."
    sudo chroot "$mount_point" /bin/busybox --install -s
    
    # Verify critical applets and create missing ones
    local critical_applets=("sh" "mount" "umount" "switch_root" "init")
    for applet in "${critical_applets[@]}"; do
        if [ -L "$mount_point/bin/$applet" ] || [ -f "$mount_point/bin/$applet" ]; then
            log_debug "Applet installed: $applet"
        else
            log_debug "Creating missing applet symlink: $applet"
            sudo ln -sf busybox "$mount_point/bin/$applet"
        fi
    done
    
    log_success "Busybox installed with applets"
}

# Install systemd components
install_systemd() {
    local mount_point="$1"
    local systemd_root="${2:-output/systemd-root}"
    
    log_info "Installing systemd components..."
    
    if [ ! -d "$systemd_root" ]; then
        log_error "Systemd root directory not found: $systemd_root"
        return 1
    fi
    
    # Copy systemd files
    sudo cp -r "$systemd_root"/* "$mount_point/"
    
    # Create systemd directories
    sudo mkdir -p "$mount_point/run/systemd"
    sudo mkdir -p "$mount_point/var/log/journal"
    sudo mkdir -p "$mount_point/etc/systemd/system"
    sudo mkdir -p "$mount_point/usr/lib/systemd/system"
    
    # Set permissions
    sudo chmod 755 "$mount_point/usr/lib/systemd/systemd"
    
    # Configure systemd for easy access
    configure_systemd_for_testing "$mount_point"
    
    log_success "Systemd components installed"
}

# Configure systemd for easier testing access
configure_systemd_for_testing() {
    local mount_point="$1"
    
    log_info "Configuring systemd for testing access..."
    
    # Set root password to empty (no password required)
    sudo sed -i 's/^root::/root::/' "$mount_point/etc/shadow"
    
    # Disable first boot wizard by creating marker files
    sudo mkdir -p "$mount_point/var/lib/systemd"
    
    # Create machine-id to skip first boot setup (as file, not directory)
    sudo sh -c "uuidgen | tr -d '-' > '$mount_point/etc/machine-id'"
    sudo touch "$mount_point/var/lib/systemd/first-boot"
    
    # Create a simple auto-login service for ttyS0
    sudo tee "$mount_point/etc/systemd/system/autologin-ttyS0.service" > /dev/null << 'EOF'
[Unit]
Description=Auto Login on ttyS0
After=systemd-user-sessions.service plymouth-quit-wait.service
Before=getty.target

[Service]
ExecStart=/bin/sh -c 'echo "Auto-login as root on ttyS0"; exec /bin/sh'
Type=idle
Restart=always
RestartSec=0
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/ttyS0
TTYReset=yes
TTYVHangup=yes

[Install]
WantedBy=getty.target
EOF

    # Create a simple auto-login service for ttysclp0  
    sudo tee "$mount_point/etc/systemd/system/autologin-ttysclp0.service" > /dev/null << 'EOF'
[Unit]
Description=Auto Login on ttysclp0
After=systemd-user-sessions.service plymouth-quit-wait.service
Before=getty.target

[Service]
ExecStart=/bin/sh -c 'echo "Auto-login as root on ttysclp0"; exec /bin/sh'
Type=idle
Restart=always
RestartSec=0
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/ttysclp0
TTYReset=yes
TTYVHangup=yes

[Install]
WantedBy=getty.target
EOF

    # Disable/mask services that interfere with testing
    sudo mkdir -p "$mount_point/etc/systemd/system"
    sudo ln -sf "/dev/null" "$mount_point/etc/systemd/system/systemd-firstboot.service"
    sudo ln -sf "/dev/null" "$mount_point/etc/systemd/system/getty@tty1.service"
    sudo ln -sf "/dev/null" "$mount_point/etc/systemd/system/serial-getty@ttyS0.service"
    sudo ln -sf "/dev/null" "$mount_point/etc/systemd/system/serial-getty@ttysclp0.service"
    
    # Enable the auto-login services
    sudo mkdir -p "$mount_point/etc/systemd/system/getty.target.wants"
    sudo ln -sf "/etc/systemd/system/autologin-ttyS0.service" "$mount_point/etc/systemd/system/getty.target.wants/"
    sudo ln -sf "/etc/systemd/system/autologin-ttysclp0.service" "$mount_point/etc/systemd/system/getty.target.wants/"
    
    # Create a simple .bashrc for root to show system info
    sudo tee "$mount_point/root/.bashrc" > /dev/null << 'EOF'
# Arch Linux s390x Root Shell
echo "Welcome to Arch Linux s390x with systemd!"
echo
echo "=== System Information ==="
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo "Systemd version: $(systemctl --version | head -n1)"
echo "Hostname: $(hostname)"
echo
echo "=== Systemd Status ==="
echo "Boot time: $(systemd-analyze | head -n1 2>/dev/null || echo 'Not available')"
echo "Failed units: $(systemctl --failed --no-legend | wc -l) unit(s)"
echo
echo "=== Available Commands ==="
echo "systemctl status    - Show systemd status"
echo "systemctl --failed  - Show failed services"
echo "journalctl -f       - Follow system logs"
echo "poweroff            - Shutdown system"
echo
EOF
    
    # Create emergency shell service
    sudo tee "$mount_point/etc/systemd/system/emergency-shell.service" > /dev/null << 'EOF'
[Unit]
Description=Emergency Shell
DefaultDependencies=false
Conflicts=shutdown.target
Before=shutdown.target

[Service]
Type=idle
ExecStart=/bin/sh
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
KillMode=process

[Install]
WantedBy=emergency.target
EOF
    
    # Add a service to show boot completion
    sudo tee "$mount_point/etc/systemd/system/boot-complete.service" > /dev/null << 'EOF'
[Unit]
Description=Boot Completion Notification
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "🚀 Arch Linux s390x boot completed successfully!"'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the boot completion service
    sudo mkdir -p "$mount_point/etc/systemd/system/multi-user.target.wants"
    sudo ln -sf "/usr/lib/systemd/system/boot-complete.service" "$mount_point/etc/systemd/system/multi-user.target.wants/boot-complete.service"
    
    log_success "Systemd configured for testing"
}

# Create init script
create_init_script() {
    local mount_point="$1"
    local use_systemd="${2:-false}"
    
    log_info "Creating init script (systemd: $use_systemd)..."
    
    if [ "$use_systemd" = "true" ]; then
        # Create systemd init wrapper
        sudo tee "$mount_point/sbin/init" > /dev/null << 'EOF'
#!/bin/sh
echo "Starting Arch Linux s390x with systemd..."

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t tmpfs tmpfs /run 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

# Create required directories
mkdir -p /run/systemd /var/log/journal

echo "=== Starting systemd ==="
exec /usr/lib/systemd/systemd
EOF
    else
        # Create busybox init script
        sudo tee "$mount_point/sbin/init" > /dev/null << 'EOF'
#!/bin/sh
echo "Welcome to Arch Linux s390x Root Filesystem!"

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

# Create TTY devices if they don't exist
for i in 1 2 3 4; do
    [ ! -c /dev/tty$i ] && mknod /dev/tty$i c 4 $i 2>/dev/null || true
done
[ ! -c /dev/console ] && mknod /dev/console c 5 1 2>/dev/null || true

echo "=== ARCH LINUX VERIFICATION ==="
[ -f /etc/os-release ] && cat /etc/os-release
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo "Init: Busybox $(busybox | head -n1)"

echo ""
echo "=== ROOT FILESYSTEM READY ==="
echo "You are now in the Arch Linux s390x root filesystem!"
echo "Available commands: $(busybox --list | tr '\n' ' ')"
echo ""

# Start shell
exec /bin/sh
EOF
    fi
    
    sudo chmod +x "$mount_point/sbin/init"
    log_success "Init script created"
}

# Mount root filesystem image
mount_rootfs() {
    local rootfs_image="$1"
    local mount_point="${2:-$ROOTFS_MOUNT_POINT}"
    
    log_info "Mounting root filesystem: $rootfs_image"
    
    if [ ! -f "$rootfs_image" ]; then
        die "Root filesystem image not found: $rootfs_image"
    fi
    
    # Create mount point
    ensure_dir "$mount_point"
    
    # Check if already mounted
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log_warning "Filesystem already mounted at $mount_point"
        return 0
    fi
    
    # Mount the image
    sudo mount -o loop "$rootfs_image" "$mount_point" || die "Failed to mount $rootfs_image"
    
    log_success "Filesystem mounted at $mount_point"
}

# Unmount root filesystem
unmount_rootfs() {
    local mount_point="${1:-$ROOTFS_MOUNT_POINT}"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log_info "Unmounting filesystem at $mount_point"
        sudo umount "$mount_point" || log_warning "Failed to unmount $mount_point"
        rmdir "$mount_point" 2>/dev/null || true
        log_success "Filesystem unmounted"
    else
        log_debug "No filesystem mounted at $mount_point"
    fi
}

# Create complete root filesystem
create_rootfs() {
    local rootfs_image="$1"
    local size_mb="${2:-$DEFAULT_ROOTFS_SIZE}"
    local install_systemd="${3:-false}"
    local busybox_binary="${4:-boot/busybox-s390x-static}"
    local systemd_root="${5:-output/systemd-root}"
    
    print_header "Creating Root Filesystem: $rootfs_image"
    start_timer
    
    # Cleanup any existing mount
    unmount_rootfs
    
    # Remove existing image
    if [ -f "$rootfs_image" ]; then
        log_info "Removing existing root filesystem image..."
        rm -f "$rootfs_image"
    fi
    
    log_info "Creating ${size_mb}MB root filesystem image..."
    
    # Create and format filesystem
    dd if=/dev/zero of="$rootfs_image" bs=1M count="$size_mb" status=progress
    mkfs.ext4 -F "$rootfs_image"
    
    # Mount filesystem
    mount_rootfs "$rootfs_image"
    
    # Create directory structure
    create_rootfs_structure "$ROOTFS_MOUNT_POINT"
    
    # Create device nodes
    create_device_nodes "$ROOTFS_MOUNT_POINT"
    
    # Create system files
    create_system_files "$ROOTFS_MOUNT_POINT"
    
    # Install busybox
    install_busybox "$ROOTFS_MOUNT_POINT" "$busybox_binary"
    
    # Install systemd if requested
    if [ "$install_systemd" = "true" ]; then
        install_systemd "$ROOTFS_MOUNT_POINT" "$systemd_root"
    fi
    
    # Create init script
    create_init_script "$ROOTFS_MOUNT_POINT" "$install_systemd"
    
    # Unmount filesystem
    unmount_rootfs
    
    # Show final information
    local size=$(get_file_size "$rootfs_image")
    log_success "Root filesystem created: $rootfs_image ($size)"
    
    if [ "$install_systemd" = "true" ]; then
        log_info "Systemd support: ENABLED"
    else
        log_info "Init system: Busybox"
    fi
    
    end_timer
}

# Quick root filesystem creation functions
create_initramfs_rootfs() {
    local rootfs_image="${1:-boot/$DEFAULT_ROOTFS_NAME}"
    create_rootfs "$rootfs_image" 50 false
}

create_busybox_rootfs() {
    local rootfs_image="${1:-boot/$DEFAULT_ROOTFS_NAME}"
    local size_mb="${2:-150}"
    create_rootfs "$rootfs_image" "$size_mb" false
}

create_systemd_rootfs() {
    local rootfs_image="${1:-boot/$DEFAULT_ROOTFS_NAME}"
    local size_mb="${2:-200}"
    create_rootfs "$rootfs_image" "$size_mb" true
}

# Initialize rootfs utilities
init_rootfs() {
    init_common
    
    # Check required commands
    check_required_commands dd mkfs.ext4 mount umount sudo
    
    # Set up cleanup trap for mount point
    setup_cleanup "$ROOTFS_MOUNT_POINT"
    
    log_debug "Root filesystem utilities initialized"
}

# Export functions for use in other scripts
export -f create_rootfs_structure create_device_nodes create_system_files
export -f install_busybox install_systemd create_init_script
export -f mount_rootfs unmount_rootfs create_rootfs
export -f create_initramfs_rootfs create_busybox_rootfs create_systemd_rootfs
export -f init_rootfs