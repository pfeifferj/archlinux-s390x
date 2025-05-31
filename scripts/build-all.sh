#!/bin/bash
# Unified build script for Arch Linux s390x port
# Handles sudo session and builds kernel + initramfs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Arch Linux s390x Build System ===${NC}"
echo

# Function to check if sudo session is active
check_sudo_session() {
    if sudo -n true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Setup sudo session if not already active
if ! check_sudo_session; then
    echo -e "${YELLOW}Setting up sudo session...${NC}"
    sudo -v || exit 1
    
    # Keep sudo session alive in background
    (
        while true; do 
            sudo -n true
            sleep 50
            kill -0 "$$" 2>/dev/null || exit
        done
    ) &
    SUDO_PID=$!
    
    # Ensure background process is killed on exit
    trap "kill $SUDO_PID 2>/dev/null" EXIT
    
    echo -e "${GREEN}✓ Sudo session established${NC}"
else
    echo -e "${GREEN}✓ Sudo session already active${NC}"
fi

# Setup toolchain path
echo -e "${YELLOW}Setting up toolchain path...${NC}"
source "$PROJECT_ROOT/setup-path.sh"

# Parse arguments
BUILD_KERNEL=true
BUILD_INITRAMFS=true
TEST_QEMU=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel-only)
            BUILD_INITRAMFS=false
            shift
            ;;
        --initramfs-only)
            BUILD_KERNEL=false
            shift
            ;;
        --test)
            TEST_QEMU=true
            shift
            ;;
        --all)
            BUILD_KERNEL=true
            BUILD_INITRAMFS=true
            TEST_QEMU=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--kernel-only|--initramfs-only|--test|--all]"
            exit 1
            ;;
    esac
done

# Build kernel
if [ "$BUILD_KERNEL" = true ]; then
    echo
    echo -e "${BLUE}=== Building Kernel ===${NC}"
    "$PROJECT_ROOT/scripts/build-kernel-container.sh"
fi

# Build initramfs
if [ "$BUILD_INITRAMFS" = true ]; then
    echo
    echo -e "${BLUE}=== Building Initramfs ===${NC}"
    "$PROJECT_ROOT/scripts/build-initramfs-final.sh"
fi

# Prepare boot files
if [ "$BUILD_KERNEL" = true ] || [ "$BUILD_INITRAMFS" = true ]; then
    echo
    echo -e "${BLUE}=== Preparing Boot Files ===${NC}"
    "$PROJECT_ROOT/scripts/prepare-boot.sh"
fi

# Test with QEMU
if [ "$TEST_QEMU" = true ]; then
    echo
    echo -e "${BLUE}=== Testing with QEMU ===${NC}"
    "$PROJECT_ROOT/scripts/test-qemu.sh"
fi

echo
echo -e "${GREEN}=== Build Complete ===${NC}"
echo -e "Output files in: ${PROJECT_ROOT}/output/"
ls -la "$PROJECT_ROOT/output/"
