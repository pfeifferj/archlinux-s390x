#!/bin/bash
# Build systemd on z/VM using scp to transfer files
# SPDX-License-Identifier: GPL-2.0-only

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/zvm-utils.sh"

# Initialize z/VM environment
init_zvm

# Build systemd using the z/VM utilities
build_on_zvm "systemd" "scripts/build-systemd-zvm.sh" "systemd-minimal-s390x.tar.gz" 1800

# Extract and organize systemd
print_section "Extracting systemd components"
rm -rf output/systemd-root
mkdir -p output/systemd-root
tar xzf output/systemd-minimal-s390x.tar.gz -C output/systemd-root

# Report results
total_size=$(du -sh output/systemd-root 2>/dev/null | cut -f1)
log_success "Systemd built and extracted successfully!"
log_info "Size: $total_size"
log_info "Location: output/systemd-root/"

# Show key files
print_section "Key systemd components"
if [ -f output/systemd-root/usr/lib/systemd/systemd ]; then
    ls -lh output/systemd-root/usr/lib/systemd/systemd
else
    log_warning "systemd binary not found"
fi

if [ -f output/systemd-root/usr/lib/systemd/systemd-journald ]; then
    ls -lh output/systemd-root/usr/lib/systemd/systemd-journald
else
    log_warning "systemd-journald not found"
fi

if [ -f output/systemd-root/usr/lib/systemd/systemd-udevd ]; then
    ls -lh output/systemd-root/usr/lib/systemd/systemd-udevd
else
    log_warning "systemd-udevd not found"
fi

if [ -f output/systemd-root/usr/bin/systemctl ]; then
    ls -lh output/systemd-root/usr/bin/systemctl
else
    log_warning "systemctl not found"
fi