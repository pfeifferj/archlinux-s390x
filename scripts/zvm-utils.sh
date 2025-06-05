#!/bin/bash
# z/VM connection and build utilities for Arch Linux s390x
# SPDX-License-Identifier: GPL-2.0-only

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# z/VM Configuration defaults
export ZVM_KEY="${ZVM_KEY:-zvm.pem}"
export SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-10}"
export SSH_STRICT_HOST_KEY_CHECKING="${SSH_STRICT_HOST_KEY_CHECKING:-no}"
export SSH_SERVER_ALIVE_INTERVAL="${SSH_SERVER_ALIVE_INTERVAL:-15}"
export SSH_SERVER_ALIVE_COUNT_MAX="${SSH_SERVER_ALIVE_COUNT_MAX:-3}"
export SCP_TIMEOUT="${SCP_TIMEOUT:-300}"
export RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-5}"
export RETRY_DELAY="${RETRY_DELAY:-10}"

# Load z/VM environment variables
load_zvm_env() {
    log_debug "Loading z/VM environment..."
    
    # Try to load from .env if variables aren't set
    if [ -z "${ZVM_HOST:-}" ] || [ -z "${ZVM_USER:-}" ]; then
        if [ -f ".env" ]; then
            log_info "Loading z/VM configuration from .env file..."
            load_env ".env"
        fi
    fi
    
    # Validate required variables
    if [ -z "${ZVM_HOST:-}" ]; then
        die "ZVM_HOST environment variable must be set"
    fi
    
    if [ -z "${ZVM_USER:-}" ]; then
        die "ZVM_USER environment variable must be set"
    fi
    
    # Set up derived variables
    export ZVM_CONNECTION="${ZVM_USER}@${ZVM_HOST}"
    export SSH_OPTS="-i $ZVM_KEY -o StrictHostKeyChecking=$SSH_STRICT_HOST_KEY_CHECKING -o ConnectTimeout=$SSH_CONNECT_TIMEOUT -o ServerAliveInterval=$SSH_SERVER_ALIVE_INTERVAL -o ServerAliveCountMax=$SSH_SERVER_ALIVE_COUNT_MAX"
    
    log_debug "z/VM connection: $ZVM_CONNECTION"
    log_debug "SSH options: $SSH_OPTS"
}

# Setup SSH key for z/VM access
setup_zvm_ssh_key() {
    if [ -n "${ZVM_SSH_KEY:-}" ] && [ ! -f "$ZVM_KEY" ]; then
        log_info "Setting up SSH key for z/VM access..."
        echo "$ZVM_SSH_KEY" > "$ZVM_KEY"
        chmod 600 "$ZVM_KEY"
        log_success "SSH key created: $ZVM_KEY"
    elif [ ! -f "$ZVM_KEY" ]; then
        die "SSH key not found: $ZVM_KEY. Set ZVM_SSH_KEY environment variable or create the key file."
    fi
}

# Test z/VM connection
test_zvm_connection() {
    log_info "Testing z/VM connection..."
    
    if ssh $SSH_OPTS "$ZVM_CONNECTION" "echo 'Connection successful'" >/dev/null 2>&1; then
        log_success "z/VM connection test passed"
        return 0
    else
        log_error "z/VM connection test failed"
        log_error "Check your SSH key, hostname, and network connectivity"
        return 1
    fi
}

# Copy file to z/VM with retry mechanism
copy_to_zvm() {
    local source_file="$1"
    local dest_path="${2:-~/}"
    local max_retries="${3:-$RETRY_MAX_ATTEMPTS}"
    
    log_info "Copying $source_file to z/VM:$dest_path"
    
    if [ ! -f "$source_file" ]; then
        die "Source file not found: $source_file"
    fi
    
    local retry_count=0
    local success=0
    
    while [ $retry_count -lt $max_retries ] && [ $success -eq 0 ]; do
        if [ $retry_count -gt 0 ]; then
            log_warning "Retry $retry_count/$max_retries - waiting ${RETRY_DELAY} seconds..."
            sleep "$RETRY_DELAY"
        fi
        
        log_debug "Attempt $((retry_count + 1)): scp $source_file to $ZVM_CONNECTION:$dest_path"
        
        # Use timeout and compression options to handle stalls
        if timeout "$SCP_TIMEOUT" scp $SSH_OPTS -C "$source_file" "$ZVM_CONNECTION:$dest_path"; then
            success=1
            log_success "Transfer completed successfully"
        else
            retry_count=$((retry_count + 1))
            log_error "Transfer failed or timed out"
            
            # Kill any stalled scp processes
            pkill -f "scp.*$(basename "$source_file")" 2>/dev/null || true
        fi
    done
    
    if [ $success -eq 0 ]; then
        die "Failed to transfer $source_file after $max_retries attempts"
    fi
}

# Copy file from z/VM with retry mechanism
copy_from_zvm() {
    local source_path="$1"
    local dest_file="$2"
    local max_retries="${3:-$RETRY_MAX_ATTEMPTS}"
    
    log_info "Copying z/VM:$source_path to $dest_file"
    
    local retry_count=0
    local success=0
    
    while [ $retry_count -lt $max_retries ] && [ $success -eq 0 ]; do
        if [ $retry_count -gt 0 ]; then
            log_warning "Retry $retry_count/$max_retries - waiting ${RETRY_DELAY} seconds..."
            sleep "$RETRY_DELAY"
        fi
        
        log_debug "Attempt $((retry_count + 1)): scp from $ZVM_CONNECTION:$source_path"
        
        # Use timeout and compression options to handle stalls
        if timeout "$SCP_TIMEOUT" scp $SSH_OPTS -C "$ZVM_CONNECTION:$source_path" "$dest_file"; then
            success=1
            log_success "Transfer completed successfully"
        else
            retry_count=$((retry_count + 1))
            log_error "Transfer failed or timed out"
            
            # Kill any stalled scp processes
            pkill -f "scp.*$(basename "$source_path")" 2>/dev/null || true
        fi
    done
    
    if [ $success -eq 0 ]; then
        die "Failed to transfer $source_path after $max_retries attempts"
    fi
}

# Execute command on z/VM
execute_on_zvm() {
    local command="$1"
    local timeout_duration="${2:-600}"
    
    log_info "Executing on z/VM: $command"
    
    if timeout "$timeout_duration" ssh $SSH_OPTS "$ZVM_CONNECTION" "$command"; then
        log_success "Command executed successfully"
        return 0
    else
        log_error "Command failed or timed out: $command"
        return 1
    fi
}

# Execute script on z/VM
execute_script_on_zvm() {
    local script_path="$1"
    local remote_path="${2:-~/$(basename "$script_path")}"
    local timeout_duration="${3:-600}"
    
    log_info "Executing script $script_path on z/VM"
    
    # Copy script to z/VM
    copy_to_zvm "$script_path" "$remote_path"
    
    # Make it executable and run it
    execute_on_zvm "chmod +x $remote_path && $remote_path" "$timeout_duration"
}

# Build component on z/VM using a build script
build_on_zvm() {
    local component_name="$1"
    local build_script="$2"
    local output_archive="${3:-${component_name}-s390x.tar.gz}"
    local timeout_duration="${4:-1800}"
    
    print_section "Building $component_name on z/VM"
    
    start_timer
    
    # Test connection first
    test_zvm_connection || die "Cannot connect to z/VM"
    
    # Execute build script
    log_info "Running build script: $build_script"
    execute_script_on_zvm "$build_script" "~/build-${component_name}.sh" "$timeout_duration"
    
    # Copy back the results
    if [ -n "$output_archive" ]; then
        log_info "Copying build artifacts..."
        ensure_dir "$OUTPUT_DIR"
        copy_from_zvm "~/$output_archive" "$OUTPUT_DIR/$output_archive"
        
        if [ -f "$OUTPUT_DIR/$output_archive" ]; then
            local size=$(get_file_size "$OUTPUT_DIR/$output_archive")
            log_success "$component_name build completed - $size archive created"
        else
            die "Build artifact not found: $OUTPUT_DIR/$output_archive"
        fi
    fi
    
    end_timer
}

# Initialize z/VM utilities
init_zvm() {
    # Initialize common environment first
    init_common
    
    # Load z/VM specific environment
    load_zvm_env
    
    # Setup SSH key
    setup_zvm_ssh_key
    
    log_debug "z/VM utilities initialized"
}

# Clean up z/VM build artifacts
cleanup_zvm_build() {
    local component_name="$1"
    local artifacts="${2:-${component_name}-s390x.tar.gz build-${component_name}.sh}"
    
    log_info "Cleaning up z/VM build artifacts for $component_name"
    
    for artifact in $artifacts; do
        execute_on_zvm "rm -f ~/$artifact" || log_warning "Failed to remove $artifact"
    done
}

# Show z/VM system information
show_zvm_info() {
    log_info "Gathering z/VM system information..."
    
    echo
    echo -e "${CYAN}=== z/VM System Information ===${NC}"
    execute_on_zvm "uname -a" || true
    execute_on_zvm "cat /etc/os-release" || true
    execute_on_zvm "df -h ~" || true
    execute_on_zvm "free -h" || true
    echo
}

# Export functions for use in other scripts
export -f load_zvm_env setup_zvm_ssh_key test_zvm_connection
export -f copy_to_zvm copy_from_zvm execute_on_zvm execute_script_on_zvm
export -f build_on_zvm init_zvm cleanup_zvm_build show_zvm_info