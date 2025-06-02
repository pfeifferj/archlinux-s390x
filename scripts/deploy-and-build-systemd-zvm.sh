#!/bin/bash
# Build systemd on z/VM using scp to transfer files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# z/VM connection details
ZVM_HOST="linux1@148.100.77.9"
ZVM_KEY="zvm.pem"

echo -e "${GREEN}=== Building systemd on z/VM RHEL 9.6 ===${NC}"

# Check if SSH key exists
if [ ! -f "$ZVM_KEY" ]; then
    echo -e "${RED}Error: SSH key $ZVM_KEY not found${NC}"
    exit 1
fi

# 1. Copy build script to z/VM
echo -e "${YELLOW}1. Copying build script to z/VM...${NC}"
scp -i $ZVM_KEY -o StrictHostKeyChecking=no scripts/build-systemd-zvm.sh $ZVM_HOST:~/

# 2. Run the build script
echo -e "${YELLOW}2. Running systemd build on z/VM (this may take 10-15 minutes)...${NC}"
ssh -i $ZVM_KEY -o StrictHostKeyChecking=no $ZVM_HOST "chmod +x ~/build-systemd-zvm.sh && ./build-systemd-zvm.sh"

# 3. Copy artifacts back
echo -e "${YELLOW}3. Copying build artifacts back...${NC}"
mkdir -p output
scp -i $ZVM_KEY -o StrictHostKeyChecking=no $ZVM_HOST:~/systemd-minimal-s390x.tar.gz output/

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