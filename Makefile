# Arch Linux s390x Port - Makefile

# Output directories
OUTPUT_DIR := output
BOOT_DIR := boot

# Output files
KERNEL := $(OUTPUT_DIR)/vmlinuz-6.6.10-s390x-arch
INITRAMFS := $(OUTPUT_DIR)/initramfs-6.6.10-s390x.img
BOOT_KERNEL := $(BOOT_DIR)/vmlinuz-linux
BOOT_INITRAMFS := $(BOOT_DIR)/initramfs-linux.img

.PHONY: all kernel busybox initramfs boot test test-rootfs test-systemd clean help container systemd

# Default target
all: boot systemd

# Build Arch Linux kernel with patches
$(KERNEL): | $(OUTPUT_DIR)
	@echo "Building Arch Linux kernel for s390x..."
	@./scripts/build-arch-kernel.sh

kernel: $(KERNEL)

# Build static busybox on z/VM (manual process)
build-busybox: | $(BOOT_DIR)
	@if [ ! -f "$(BOOT_DIR)/busybox-s390x-static" ]; then \
		echo "❌ ERROR: Static busybox not found!"; \
		echo ""; \
		echo "To build busybox, you must:"; \
		echo "1. SSH into z/VM: ssh -i zvm.pem -o StrictHostKeyChecking=no \$$ZVM_USER@\$$ZVM_HOST"; \
		echo "2. Run the build script: ./scripts/build-busybox-zvm.sh"; \
		echo "3. Transfer the resulting busybox binary back to: $(BOOT_DIR)/busybox-s390x-static"; \
		echo ""; \
		echo "The busybox MUST be built natively on s390x hardware for proper static linking."; \
		exit 1; \
	else \
		echo "✅ Static busybox already exists at $(BOOT_DIR)/busybox-s390x-static"; \
	fi


# Check busybox binary (must be static build from z/VM)
busybox: build-busybox
	@echo "✅ Busybox check complete"

# Build initramfs (depends on busybox)
$(INITRAMFS): busybox | $(OUTPUT_DIR)
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

# Common validation for test targets
define check_boot_files
	@if [ ! -f "$(BOOT_DIR)/vmlinuz-linux" ] || [ ! -f "$(BOOT_DIR)/initramfs-linux.img" ]; then \
		echo "Error: Boot files not found. Run 'make all' first"; \
		exit 1; \
	fi
endef

# Test with QEMU (initramfs-only)
test:
	$(call check_boot_files)
	@echo "Testing s390x system with QEMU (initramfs-only)..."
	@./scripts/test-qemu.sh initramfs

# Test with root filesystem
test-rootfs:
	$(call check_boot_files)
	@echo "Testing s390x system with root filesystem..."
	@./scripts/test-qemu.sh rootfs

# Test with systemd as init
test-systemd:
	$(call check_boot_files)
	@if [ ! -d "output/systemd-root" ]; then \
		echo "Error: Systemd not found. Run 'make systemd' first"; \
		exit 1; \
	fi
	@echo "Testing s390x system with systemd..."
	@./scripts/test-qemu.sh systemd

# Create directories
$(OUTPUT_DIR):
	@mkdir -p $@

boot-dir:
	@mkdir -p $(BOOT_DIR)

# Build systemd on z/VM (native s390x compilation)
systemd-zvm:
	@echo "Building systemd on z/VM..."
	@./scripts/deploy-and-build-systemd-zvm.sh

# Build systemd (alias for z/VM build)
systemd: systemd-zvm

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@if [ -d "$(OUTPUT_DIR)" ]; then \
		if ! rm -rf $(OUTPUT_DIR)/* 2>/dev/null; then \
			echo "Permission denied. Trying with sudo..."; \
			sudo rm -rf $(OUTPUT_DIR)/*; \
		fi; \
	fi
	@rm -f $(BOOT_KERNEL) $(BOOT_INITRAMFS) 2>/dev/null || true
	@echo "Clean complete."

# Show help
help:
	@echo "Arch Linux s390x Port - Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all            - Build everything (kernel + initramfs + systemd)"
	@echo "  kernel         - Build Arch Linux kernel with patches for s390x"
	@echo "  busybox        - Check for static s390x busybox (must be built on z/VM)"
	@echo "  initramfs      - Build initramfs only (requires busybox)"
	@echo "  boot           - Prepare boot directory"
	@echo "  container      - Build development container"
	@echo "  systemd        - Build minimal systemd on z/VM (native s390x)"
	@echo "  test           - Test with QEMU s390x emulation (initramfs only)"
	@echo "  test-rootfs    - Test with QEMU and minimal root filesystem"
	@echo "  test-systemd   - Test with QEMU and systemd as init"
	@echo "  clean          - Remove build artifacts"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Quick start:"
	@echo "  make container  - Build development container (first time only)"
	@echo "  make all        - Build complete system"
	@echo "  make test       - Test the built system"