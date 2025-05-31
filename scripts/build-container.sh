#!/bin/bash
# Build the consolidated s390x development container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building consolidated s390x development container..."

# Build the container using the Containerfile in project root
sudo podman build -t s390x-archlinux-dev -f "$PROJECT_ROOT/Containerfile" "$PROJECT_ROOT"

echo "✅ Container 's390x-archlinux-dev' built successfully!"
echo ""
echo "This container includes:"
echo "- s390x cross-compilation toolchain"  
echo "- Kernel build dependencies"
echo "- mkinitcpio with upgraded meson (1.8.1)"
echo "- All necessary build tools"
