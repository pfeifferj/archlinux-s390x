#!/bin/bash
# Unified QEMU testing script for Arch Linux s390x
# SPDX-License-Identifier: GPL-2.0-only

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/create-rootfs.sh"

# Test configuration
TEST_MODE="${1:-initramfs}"
ROOTFS_SIZE="${2:-150}"

# Initialize
init_common

# Change to project root
cd "$PROJECT_ROOT"

# Validate boot files exist
check_required_files "boot/vmlinuz-linux" "boot/initramfs-linux.img"

# Test functions
test_initramfs_only() {
    print_header "Testing Arch Linux s390x - Initramfs Only"
    
    log_info "Starting QEMU with initramfs-only boot..."
    log_info "This will boot into the initramfs environment with busybox shell"
    log_info "Press Ctrl-A X to exit QEMU"
    echo
    
    run_qemu_s390x "rdinit=/init"
}

test_rootfs_boot() {
    print_header "Testing Arch Linux s390x - Root Filesystem"
    
    local rootfs_img="boot/rootfs-s390x.img"
    
    # Create root filesystem if it doesn't exist or is older than busybox
    if [ ! -f "$rootfs_img" ] || [ "boot/busybox-s390x-static" -nt "$rootfs_img" ]; then
        log_info "Creating root filesystem..."
        create_busybox_rootfs "$rootfs_img" "$ROOTFS_SIZE"
    else
        log_info "Using existing root filesystem: $rootfs_img"
    fi
    
    log_info "Starting QEMU with root filesystem switching..."
    log_info "This will boot from initramfs, then switch to root filesystem"
    log_info "Expected: Arch Linux identification and busybox shell on root filesystem"
    log_info "Press Ctrl-A X to exit QEMU"
    echo
    
    run_qemu_s390x "root=/dev/vda rw init=/sbin/init" \
        "-drive file=$rootfs_img,format=raw,if=none,id=rootdisk -device virtio-blk-ccw,drive=rootdisk"
}

test_systemd_boot() {
    print_header "Testing Arch Linux s390x - Systemd"
    
    local rootfs_img="boot/rootfs-s390x.img"
    
    # Check if systemd is available
    if [ ! -d "output/systemd-root" ]; then
        die "Systemd not found. Run 'make systemd' first to build systemd components"
    fi
    
    # Create systemd root filesystem
    log_info "Creating systemd root filesystem..."
    create_systemd_rootfs "$rootfs_img" "$ROOTFS_SIZE"
    
    log_info "Starting QEMU with systemd as init..."
    log_info "This will boot with systemd as PID 1"
    log_info "Expected: 'Welcome to Arch Linux!' and systemd boot sequence"
    log_info "Press Ctrl-A X to exit QEMU"
    echo
    
    run_qemu_s390x "root=/dev/vda rw init=/usr/lib/systemd/systemd systemd.log_level=debug" \
        "-drive file=$rootfs_img,format=raw,if=virtio -serial mon:stdio"
}

test_qemu_info() {
    print_header "QEMU System Information"
    
    log_info "QEMU s390x version:"
    qemu-system-s390x --version || log_warning "QEMU s390x not found"
    
    echo
    log_info "Available s390x machines:"
    qemu-system-s390x -machine help | grep s390 || true
    
    echo
    log_info "Boot files status:"
    if [ -f "boot/vmlinuz-linux" ]; then
        local kernel_size=$(get_file_size "boot/vmlinuz-linux")
        log_success "Kernel: boot/vmlinuz-linux ($kernel_size)"
    else
        log_error "Kernel: boot/vmlinuz-linux (missing)"
    fi
    
    if [ -f "boot/initramfs-linux.img" ]; then
        local initramfs_size=$(get_file_size "boot/initramfs-linux.img")
        log_success "Initramfs: boot/initramfs-linux.img ($initramfs_size)"
    else
        log_error "Initramfs: boot/initramfs-linux.img (missing)"
    fi
    
    if [ -f "boot/rootfs-s390x.img" ]; then
        local rootfs_size=$(get_file_size "boot/rootfs-s390x.img")
        log_success "Root filesystem: boot/rootfs-s390x.img ($rootfs_size)"
    else
        log_info "Root filesystem: boot/rootfs-s390x.img (will be created)"
    fi
    
    echo
    log_info "Systemd availability:"
    if [ -d "output/systemd-root" ]; then
        log_success "Systemd: Available in output/systemd-root"
    else
        log_warning "Systemd: Not available (run 'make systemd' to build)"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [MODE] [ROOTFS_SIZE]

MODES:
  initramfs    Test initramfs-only system (default)
  rootfs       Test with root filesystem switching  
  systemd      Test with systemd as init system
  info         Show system information and file status

ROOTFS_SIZE:
  Size in MB for root filesystem creation (default: 150)

Examples:
  $0                    # Test initramfs-only (default)
  $0 rootfs             # Test root filesystem with default size
  $0 systemd 200        # Test systemd with 200MB root filesystem
  $0 info               # Show system information

Notes:
  - All tests require boot/vmlinuz-linux and boot/initramfs-linux.img
  - Systemd test requires 'make systemd' to be run first
  - Root filesystem will be created automatically if needed
  - Press Ctrl-A X to exit QEMU during testing
EOF
}

# Main execution
case "$TEST_MODE" in
    "initramfs"|"initramfs-only")
        test_initramfs_only
        ;;
    "rootfs"|"root"|"filesystem")
        test_rootfs_boot
        ;;
    "systemd"|"systemd-boot")
        test_systemd_boot
        ;;
    "info"|"status")
        test_qemu_info
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        log_error "Unknown test mode: $TEST_MODE"
        echo
        show_usage
        exit 1
        ;;
esac