#!/bin/bash
# Build the consolidated s390x development container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building consolidated s390x development container..."
echo "Using multi-stage build for improved caching..."

# Enable BuildKit-like features in podman for better layer caching
export BUILDAH_LAYERS=true

# Build the container using the Containerfile in project root
# Use --jobs for parallel downloads and --layers for better caching
sudo sudo podman build \
    --jobs 4 \
    --layers \
    -t s390x-archlinux-dev \
    -f "$PROJECT_ROOT/Containerfile" \
    "$PROJECT_ROOT"

echo "Success: Container 's390x-archlinux-dev' built successfully!"
echo ""
echo "This container includes:"
echo "- s390x cross-compilation toolchain"  
echo "- Kernel build dependencies"
echo "- mkinitcpio with upgraded meson (>=1.4.0)"
echo "- All necessary build tools"
echo ""
echo "Image details:"
sudo sudo podman images s390x-archlinux-dev:latest --format "table {{.Repository}} {{.Tag}} {{.Size}}"
