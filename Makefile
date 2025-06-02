# Arch Linux s390x Port - Makefile

# Output directories
OUTPUT_DIR := output
BOOT_DIR := boot

# Output files
KERNEL := $(OUTPUT_DIR)/arch/s390/boot/bzImage
INITRAMFS := $(OUTPUT_DIR)/initramfs-6.6.10-s390x.img
BUSYBOX := $(BOOT_DIR)/busybox-s390x-native
BOOT_KERNEL := $(BOOT_DIR)/vmlinuz-linux
BOOT_INITRAMFS := $(BOOT_DIR)/initramfs-linux.img

.PHONY: all kernel build-busybox busybox initramfs boot test test-rootfs clean help container

# Default target
all: boot

# Build kernel
$(KERNEL): | $(OUTPUT_DIR)
	@echo "Building s390x kernel..."
	@./scripts/build-kernel-container.sh

kernel: $(KERNEL)

# Build static busybox on z/VM (manual process)
build-busybox: | $(BOOT_DIR)
	@if [ ! -f "$(BOOT_DIR)/busybox-s390x-static" ]; then \
		echo "❌ ERROR: Static busybox not found!"; \
		echo ""; \
		echo "To build busybox, you must:"; \
		echo "1. SSH into z/VM: ssh -i zvm.pem -o StrictHostKeyChecking=no linux1@148.100.77.9"; \
		echo "2. Run the build script: ./scripts/build-busybox-zvm.sh"; \
		echo "3. Transfer the resulting busybox binary back to: $(BOOT_DIR)/busybox-s390x-static"; \
		echo ""; \
		echo "The busybox MUST be built natively on s390x hardware for proper static linking."; \
		exit 1; \
	else \
		echo "✅ Static busybox already exists at $(BOOT_DIR)/busybox-s390x-static"; \
	fi

# Download busybox fallback (deprecated - use z/VM build)
download-busybox: | $(OUTPUT_DIR)
	@echo "❌ Dynamic busybox download is deprecated"
	@echo "Use z/VM static compilation instead:"
	@echo "  ssh -i zvm.pem linux1@148.100.77.9"
	@echo "  # Follow build-busybox-zvm.sh instructions"
	@exit 1

# Check busybox binary (prefers static build)
$(BUSYBOX): | build-busybox
	@if [ -f "$(BOOT_DIR)/busybox-s390x-static" ]; then \
		ln -sf busybox-s390x-static $(BUSYBOX); \
		echo "✅ Using static busybox"; \
	elif [ -f "$(BUSYBOX)" ]; then \
		echo "✅ Using existing busybox"; \
	else \
		echo "ERROR: No busybox binary found"; \
		exit 1; \
	fi

busybox: $(BUSYBOX)

# Build initramfs (depends on busybox)
$(INITRAMFS): $(BUSYBOX) | $(OUTPUT_DIR)
	@echo "Building initramfs with mkinitcpio..."
	@./scripts/build-initramfs-final.sh

initramfs: $(INITRAMFS)

# Prepare boot files (depends on kernel and initramfs)
boot: $(KERNEL) $(INITRAMFS) | boot-dir
	@echo "Preparing boot directory..."
	@./scripts/prepare-boot.sh

# Build container if needed
container:
	@echo "Building s390x-archlinux-dev container..."
	@./scripts/build-container.sh

# Test with QEMU (assumes boot files already exist)
test:
	@if [ ! -f "$(BOOT_DIR)/vmlinuz-linux" ] || [ ! -f "$(BOOT_DIR)/initramfs-linux.img" ]; then \
		echo "Error: Boot files not found. Run 'make all' first"; \
		exit 1; \
	fi
	@echo "Testing s390x system with QEMU..."
	@./scripts/run-qemu-initramfs-only.sh

# Test with root filesystem (creates minimal rootfs and boots to it)
test-rootfs:
	@if [ ! -f "$(BOOT_DIR)/vmlinuz-linux" ] || [ ! -f "$(BOOT_DIR)/initramfs-linux.img" ]; then \
		echo "Error: Boot files not found. Run 'make all' first"; \
		exit 1; \
	fi
	@echo "Testing s390x system with root filesystem..."
	@./scripts/test-qemu-rootfs.sh

# Create directories
$(OUTPUT_DIR):
	@mkdir -p $@

boot-dir:
	@mkdir -p $(BOOT_DIR)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)/*
	@rm -f $(BOOT_KERNEL) $(BOOT_INITRAMFS)
	@echo "Clean complete."

# Show help
help:
	@echo "Arch Linux s390x Port - Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all            - Build everything (kernel + initramfs + boot)"
	@echo "  kernel         - Build s390x kernel only"
	@echo "  build-busybox  - Check for static s390x busybox (must be built on z/VM)"
	@echo "  busybox        - Check s390x busybox binary exists"
	@echo "  initramfs      - Build initramfs only (requires busybox)"
	@echo "  boot           - Prepare boot directory"
	@echo "  container      - Build development container"
	@echo "  test           - Test with QEMU s390x emulation (initramfs only)"
	@echo "  test-rootfs    - Test with QEMU and minimal root filesystem"
	@echo "  clean          - Remove build artifacts"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Quick start:"
	@echo "  make container  - Build development container (first time only)"
	@echo "  make all        - Build complete system"
	@echo "  make test       - Test the built system"