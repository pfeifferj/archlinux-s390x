# Arch Linux s390x Port - Makefile

.PHONY: all kernel initramfs boot test clean help

# Default target
all: kernel initramfs boot

# Build kernel
kernel:
	@echo "Building s390x kernel..."
	@./scripts/build-all.sh --kernel-only

# Build initramfs
initramfs:
	@echo "Building initramfs with mkinitcpio..."
	@./scripts/build-all.sh --initramfs-only

# Prepare boot files
boot:
	@echo "Preparing boot directory..."
	@./scripts/prepare-boot.sh

# Test with QEMU
test:
	@echo "Testing s390x system with QEMU..."
	@./scripts/run-qemu-initramfs-only.sh

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf output/*
	@rm -f boot/vmlinuz-linux boot/initramfs-linux.img
	@echo "Clean complete."

# Show help
help:
	@echo "Arch Linux s390x Port - Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build everything (kernel + initramfs + boot)"
	@echo "  kernel     - Build s390x kernel only"
	@echo "  initramfs  - Build initramfs only"
	@echo "  boot       - Prepare boot directory"
	@echo "  test       - Test with QEMU s390x emulation"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Quick start:"
	@echo "  make all   - Build complete system"
	@echo "  make test  - Test the built system"