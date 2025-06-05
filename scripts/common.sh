#!/bin/bash
# Common utilities for Arch Linux s390x build system
# SPDX-License-Identifier: GPL-2.0-only

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# Get project root directory
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

# Get project paths
get_project_paths() {
    export PROJECT_ROOT="$(get_project_root)"
    export OUTPUT_DIR="$PROJECT_ROOT/output"
    export BOOT_DIR="$PROJECT_ROOT/boot"
    export BUILD_DIR="$PROJECT_ROOT/build-kernel"
    export SCRIPTS_DIR="$PROJECT_ROOT/scripts"
    export PATCHES_DIR="$PROJECT_ROOT/patches"
    export CONFIG_DIR="$PROJECT_ROOT/config"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1" >&2
    fi
}

# Error handling
die() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running in container
is_container() {
    [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ "${container:-}" = "podman" ]
}

# Validate required commands
check_required_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
}

# Validate required files
check_required_files() {
    local missing=()
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            missing+=("$file")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required files: ${missing[*]}"
        return 1
    fi
}

# Validate required directories
check_required_dirs() {
    local missing=()
    for dir in "$@"; do
        if [ ! -d "$dir" ]; then
            missing+=("$dir")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required directories: ${missing[*]}"
        return 1
    fi
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}

# Load environment from .env file if it exists
load_env() {
    local env_file="${1:-.env}"
    if [ -f "$env_file" ]; then
        log_debug "Loading environment from $env_file"
        set -a
        source "$env_file"
        set +a
        log_debug "Environment loaded successfully"
    else
        log_debug "No .env file found at $env_file"
    fi
}

# Print script header
print_header() {
    local title="$1"
    local width=60
    echo
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${CYAN}$(printf '%-*s' $width "$title")${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo
}

# Print section separator
print_section() {
    local title="$1"
    echo
    echo -e "${YELLOW}=== $title ===${NC}"
}

# Cleanup function for temporary files
cleanup_on_exit() {
    local temp_files=("$@")
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            log_debug "Cleaning up temporary file: $file"
            rm -f "$file"
        fi
    done
}

# Set up cleanup trap
setup_cleanup() {
    local temp_files=("$@")
    trap 'cleanup_on_exit "${temp_files[@]}"' EXIT INT TERM
}

# Progress indicator
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width=40
    local progress=$((current * width / total))
    local remaining=$((width - progress))
    
    printf "\r${CYAN}[%s%s] %d/%d %s${NC}" \
        "$(printf '#%.0s' $(seq 1 $progress))" \
        "$(printf '.%.0s' $(seq 1 $remaining))" \
        "$current" "$total" "$message"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Timer functions
start_timer() {
    export TIMER_START=$(date +%s)
}

end_timer() {
    local start_time="${TIMER_START:-$(date +%s)}"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    if [ $minutes -gt 0 ]; then
        echo -e "${CYAN}Completed in ${minutes}m ${seconds}s${NC}"
    else
        echo -e "${CYAN}Completed in ${seconds}s${NC}"
    fi
}

# File size formatting
format_size() {
    local size="$1"
    if [ "$size" -ge 1073741824 ]; then
        echo "$((size / 1073741824))GB"
    elif [ "$size" -ge 1048576 ]; then
        echo "$((size / 1048576))MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$((size / 1024))KB"
    else
        echo "${size}B"
    fi
}

# Get file size in human readable format
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        format_size "$size"
    else
        echo "N/A"
    fi
}

# Common QEMU configuration
run_qemu_s390x() {
    local append_args="$1"
    local extra_args="${2:-}"
    
    check_required_commands qemu-system-s390x
    check_required_files "boot/vmlinuz-linux" "boot/initramfs-linux.img"
    
    log_info "Starting QEMU s390x system..."
    log_debug "Append args: $append_args"
    log_debug "Extra args: $extra_args"
    
    qemu-system-s390x \
        -machine s390-ccw-virtio \
        -cpu max \
        -m 2G \
        -kernel "boot/vmlinuz-linux" \
        -initrd "boot/initramfs-linux.img" \
        -append "console=ttyS0 $append_args" \
        -nographic \
        -device virtio-net-ccw,netdev=net0 \
        -netdev user,id=net0 \
        $extra_args
}

# Initialize common environment
init_common() {
    # Set strict error handling
    set -euo pipefail
    
    # Initialize paths
    get_project_paths
    
    # Load environment if available
    load_env
    
    # Ensure output directory exists
    ensure_dir "$OUTPUT_DIR"
}

# Export functions for use in other scripts
export -f get_project_root get_project_paths
export -f log_info log_success log_warning log_error log_debug die
export -f command_exists is_container
export -f check_required_commands check_required_files check_required_dirs
export -f ensure_dir load_env
export -f print_header print_section
export -f cleanup_on_exit setup_cleanup
export -f show_progress start_timer end_timer
export -f format_size get_file_size
export -f run_qemu_s390x init_common