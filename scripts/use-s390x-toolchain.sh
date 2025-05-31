#!/bin/bash
# Wrapper to use s390x toolchain from Podman

# If no arguments, run interactive shell
if [ $# -eq 0 ]; then
    sudo podman run --rm -it \
        -v "$PWD:/workspace" \
        -v "$HOME/.cache:/root/.cache" \
        s390x-toolchain \
        bash
else
    # Run command
    sudo podman run --rm \
        -v "$PWD:/workspace" \
        -v "$HOME/.cache:/root/.cache" \
        s390x-toolchain \
        "$@"
fi
