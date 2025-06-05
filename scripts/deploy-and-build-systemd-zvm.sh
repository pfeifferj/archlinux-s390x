#!/bin/bash
# Build systemd on z/VM using scp to transfer files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment variables from .env file if available and variables not set
if [ -z "$ZVM_HOST" ] || [ -z "$ZVM_USER" ]; then
    if [ -f ".env" ]; then
        echo -e "${YELLOW}Loading z/VM configuration from .env file...${NC}"
        set -a  # Export all variables
        source .env
        set +a  # Stop exporting
    fi
fi

# Check if required variables are now set
if [ -z "$ZVM_HOST" ] || [ -z "$ZVM_USER" ]; then
    echo -e "${RED}Error: ZVM_HOST and ZVM_USER environment variables must be set${NC}"
    echo ""
    echo "Option 1: Create a .env file (recommended):"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your z/VM details"
    echo ""
    echo "Option 2: Export variables manually:"
    echo "  export ZVM_HOST=your.zvm.host"
    echo "  export ZVM_USER=your_username"
    echo "  export ZVM_SSH_KEY='your-ssh-key-content'"
    exit 1
fi

ZVM_CONNECTION="${ZVM_USER}@${ZVM_HOST}"
ZVM_KEY="${ZVM_KEY:-zvm.pem}"

echo -e "${GREEN}=== Building systemd on z/VM RHEL 9.6 ===${NC}"

# Check if SSH key exists
if [ ! -f "$ZVM_KEY" ]; then
    echo -e "${RED}Error: SSH key $ZVM_KEY not found${NC}"
    exit 1
fi

# SSH options
SSH_OPTS="-i $ZVM_KEY -o StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING:-no} -o ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"

# 1. Copy build script to z/VM
echo -e "${YELLOW}1. Copying build script to z/VM...${NC}"
scp $SSH_OPTS scripts/build-systemd-zvm.sh $ZVM_CONNECTION:~/

# 2. Run the build script
echo -e "${YELLOW}2. Running systemd build on z/VM (this may take 10-15 minutes)...${NC}"
ssh $SSH_OPTS $ZVM_CONNECTION "chmod +x ~/build-systemd-zvm.sh && ./build-systemd-zvm.sh"

# 3. Copy artifacts back with retry mechanism
echo -e "${YELLOW}3. Copying build artifacts back...${NC}"
mkdir -p output

# Function to copy with retries
copy_with_retry() {
    local max_retries=5
    local retry_count=0
    local success=0
    
    while [ $retry_count -lt $max_retries ] && [ $success -eq 0 ]; do
        if [ $retry_count -gt 0 ]; then
            echo -e "${YELLOW}Retry $retry_count/$max_retries - waiting 10 seconds before retrying...${NC}"
            sleep 10
        fi
        
        # Use timeout and compression options to handle stalls
        if timeout 300 scp $SSH_OPTS -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -C $ZVM_CONNECTION:~/systemd-minimal-s390x.tar.gz output/; then
            success=1
            echo -e "${GREEN}✓ Transfer completed successfully${NC}"
        else
            retry_count=$((retry_count + 1))
            echo -e "${RED}Transfer failed or timed out${NC}"
            
            # Kill any stalled scp processes
            pkill -f "scp.*systemd-minimal-s390x.tar.gz" 2>/dev/null || true
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo -e "${RED}Failed to transfer after $max_retries attempts${NC}"
        echo -e "${YELLOW}You can manually copy the file with:${NC}"
        echo "scp $SSH_OPTS $ZVM_CONNECTION:~/systemd-minimal-s390x.tar.gz output/"
        exit 1
    fi
}

# Perform the copy with retries
copy_with_retry

# 4. Extract and organize
echo -e "${YELLOW}4. Extracting systemd...${NC}"
rm -rf output/systemd-root
mkdir -p output/systemd-root
tar xzf output/systemd-minimal-s390x.tar.gz -C output/systemd-root

# 5. Report results
echo -e "${GREEN}✓ Systemd built and extracted successfully!${NC}"
TOTAL_SIZE=$(du -sh output/systemd-root 2>/dev/null | cut -f1)
echo -e "${GREEN}Size: $TOTAL_SIZE${NC}"
echo -e "${GREEN}Location: output/systemd-root/${NC}"

# Show key files
echo -e "${YELLOW}Key systemd components:${NC}"
[ -f output/systemd-root/usr/lib/systemd/systemd ] && ls -lh output/systemd-root/usr/lib/systemd/systemd
[ -f output/systemd-root/usr/lib/systemd/systemd-journald ] && ls -lh output/systemd-root/usr/lib/systemd/systemd-journald
[ -f output/systemd-root/usr/lib/systemd/systemd-udevd ] && ls -lh output/systemd-root/usr/lib/systemd/systemd-udevd
[ -f output/systemd-root/usr/bin/systemctl ] && ls -lh output/systemd-root/usr/bin/systemctl