# Makefile - MMUKO-OS Build System
# Supports: Windows, Linux, macOS, WSL

# Targets
BUILD_DIR = build
IMG_DIR = img
BOOT_DIR = boot
IMG_NAME = mmuko-os.img
IMG_PATH = $(IMG_DIR)/$(IMG_NAME)
BOOT_DIRECT_IMAGE = $(BOOT_DIR)/build/mmuko-direct.img
VBOX_RAW = $(IMG_DIR)/mmuko-os-vbox.raw
VBOX_DISK = $(IMG_DIR)/mmuko-os.vdi
VBOX_SERIAL = $(IMG_DIR)/vbox-serial.log
VBOX_VM_NAME ?= MMUKO-OS-RingBoot
VBOX_MEMORY ?= 64
VBOX_VRAM ?= 4
OBIELF ?= 0
OBIELF_DIR ?= ../../obielf
OBIELF_MANIFEST ?= $(OBIELF_DIR)/Cargo.toml
OBIELF_FORMAT ?= obielf64
OBIELF_PROFILE ?= debug
OBIELF_TARGET_DIR ?= target
OBIELF_CARGO_TARGET_DIR ?= $(BUILD_DIR)/cargo-obielf
OBIELF_RUN = cargo run --quiet --manifest-path "$(OBIELF_MANIFEST)" --target-dir "$(OBIELF_CARGO_TARGET_DIR)" --bin obielf --
GO ?= go

VERIFY_OBIELF =
ifeq ($(OBIELF),1)
VERIFY_OBIELF = obielf-preview
endif

ifeq ($(OS),Windows_NT)
PYTHON ?= py -3 -X utf8
MKDIR_IMG = powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force '$(IMG_DIR)' | Out-Null"
MKDIR_BUILD = powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force '$(BUILD_DIR)' | Out-Null"
RM_GENERATED = powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force '$(BUILD_DIR)','$(IMG_DIR)','-p' -ErrorAction SilentlyContinue"
VBOXMANAGE ?= C:/Program Files/Oracle/VirtualBox/VBoxManage.exe
VBOXMANAGE_CMD = "$(VBOXMANAGE)"
VBOX_CHECK = if not exist "$(VBOXMANAGE)" (echo ERROR: VBoxManage not found at "$(VBOXMANAGE)" && exit /b 1)
VBOX_REMOVE_DISK = if exist "$(VBOX_DISK)" del /f /q "$(VBOX_DISK)"
VBOX_PREPARE_RAW = powershell -NoProfile -ExecutionPolicy Bypass -Command "$$src='$(abspath $(IMG_PATH))'; $$dst='$(abspath $(VBOX_RAW))'; $$bytes=[IO.File]::ReadAllBytes($$src); $$raw=New-Object byte[] 1048576; [Array]::Copy($$bytes,0,$$raw,0,$$bytes.Length); [IO.File]::WriteAllBytes($$dst,$$raw)"
FAIL_UNSUPPORTED = exit /b 1
EXE_EXT = .exe
else
PYTHON ?= python3
MKDIR_IMG = mkdir -p $(IMG_DIR)
MKDIR_BUILD = mkdir -p $(BUILD_DIR)
RM_GENERATED = rm -rf $(BUILD_DIR) $(IMG_DIR) -p
VBOXMANAGE ?= VBoxManage
VBOXMANAGE_CMD = "$(VBOXMANAGE)"
VBOX_CHECK = command -v "$(VBOXMANAGE)" >/dev/null 2>&1 || (echo "ERROR: VBoxManage not found at $(VBOXMANAGE)" && exit 1)
VBOX_REMOVE_DISK = rm -f "$(VBOX_DISK)"
VBOX_PREPARE_RAW = cp "$(IMG_PATH)" "$(VBOX_RAW)" && truncate -s 1M "$(VBOX_RAW)"
FAIL_UNSUPPORTED = exit 1
EXE_EXT =
endif

LTF_CODEC_EXE = $(BUILD_DIR)/nsigii-codec$(EXE_EXT)

.DEFAULT_GOAL := help

.PHONY: boot boot-direct boot-run-direct verify vbox clean help img all test cpp csharp boot-clean obielf-build obielf-install obielf-formats obielf-package-img obielf-package-boot obielf-preview examples examples-trident examples-lt-fileformat

all test cpp csharp boot-clean:
	@echo "Target '$@' is not supported. Run 'make help' for supported MMUKO-OS commands."
	@$(FAIL_UNSUPPORTED)

# Generate boot image
img:
	$(MKDIR_IMG)
	$(PYTHON) build_img.py $(IMG_PATH)

# Build imported MMUKO boot implementation
boot:
	$(MAKE) -C $(BOOT_DIR) OBIELF=$(OBIELF)

boot-direct:
	$(MAKE) -C $(BOOT_DIR) direct OBIELF=$(OBIELF)

boot-run-direct:
	$(MAKE) -C $(BOOT_DIR) run-direct OBIELF=$(OBIELF)

# Build and package the local OBIELF toolchain view of MMUKO artifacts.
obielf-build:
	$(MKDIR_BUILD)
	cargo build --manifest-path "$(OBIELF_MANIFEST)" --target-dir "$(OBIELF_CARGO_TARGET_DIR)"

obielf-install:
	cargo install --path "$(OBIELF_DIR)"

obielf-formats:
	$(MKDIR_BUILD)
	$(OBIELF_RUN) formats

obielf-package-img: img
	$(MKDIR_BUILD)
	$(OBIELF_RUN) package --format $(OBIELF_FORMAT) --kind executable --name mmuko-os --profile $(OBIELF_PROFILE) --target-dir "$(OBIELF_TARGET_DIR)" "$(IMG_PATH)"

obielf-package-boot: boot-direct
	$(MKDIR_BUILD)
	$(OBIELF_RUN) package --format $(OBIELF_FORMAT) --kind executable --name mmuko-boot --profile $(OBIELF_PROFILE) --target-dir "$(OBIELF_TARGET_DIR)" "$(BOOT_DIRECT_IMAGE)"

obielf-preview: obielf-formats obielf-package-img
	@echo "OBIELF preview packaged MMUKO-OS as $(OBIELF_FORMAT) executable metadata."

# Build or locate examples that demonstrate the boot and LTF surfaces.
examples: examples-trident examples-lt-fileformat

examples-trident:
	@echo "Trident boot visualizer: $(CURDIR)/examples/trident-boot/index.html"
	@echo "Open the file in a browser; it is static HTML and Canvas."

examples-lt-fileformat:
	$(MKDIR_BUILD)
	$(GO) build -o "$(LTF_CODEC_EXE)" ./examples/lt-fileformat/main.go
	@echo "LTF/NSIGII codec built: $(LTF_CODEC_EXE)"

# Clean build artifacts
clean:
	$(RM_GENERATED)
	$(MAKE) -C $(BOOT_DIR) clean

# Verify boot images and mmuko-boot integration
verify: img boot-direct $(VERIFY_OBIELF)
	@echo "=== MMUKO-OS Verification ==="
	@echo "RIFT image: $(IMG_PATH)"
	@echo "mmuko-boot direct image: $(BOOT_DIRECT_IMAGE)"
	@echo "Boot phases: SPARSE -> REMEMBER -> ACTIVE -> VERIFY"
	@echo "NSIGII target: 0x55"
	@echo "OBIELF integration: $(OBIELF)"

# VirtualBox boot test
vbox: img
	@$(VBOX_CHECK)
	-$(VBOXMANAGE_CMD) controlvm "$(VBOX_VM_NAME)" poweroff
	-$(VBOXMANAGE_CMD) unregistervm "$(VBOX_VM_NAME)" --delete
	-$(VBOX_REMOVE_DISK)
	$(VBOX_PREPARE_RAW)
	$(VBOXMANAGE_CMD) convertfromraw "$(abspath $(VBOX_RAW))" "$(abspath $(VBOX_DISK))" --format VDI
	$(VBOXMANAGE_CMD) createvm --name "$(VBOX_VM_NAME)" --ostype "Other" --register
	$(VBOXMANAGE_CMD) modifyvm "$(VBOX_VM_NAME)" --memory $(VBOX_MEMORY) --vram $(VBOX_VRAM) --firmware bios --boot1 disk --boot2 none --boot3 none --boot4 none --ioapic off --pae off
	$(VBOXMANAGE_CMD) storagectl "$(VBOX_VM_NAME)" --name "IDE" --add ide --controller PIIX4
	$(VBOXMANAGE_CMD) storageattach "$(VBOX_VM_NAME)" --storagectl "IDE" --port 0 --device 0 --type hdd --medium "$(abspath $(VBOX_DISK))"
	$(VBOXMANAGE_CMD) modifyvm "$(VBOX_VM_NAME)" --uart1 0x3F8 4 --uartmode1 file "$(abspath $(VBOX_SERIAL))"
	$(VBOXMANAGE_CMD) startvm "$(VBOX_VM_NAME)" --type gui

# Help
help:
	@echo "MMUKO-OS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  img     - Create bootable image"
	@echo "  boot    - Build imported boot implementation default"
	@echo "  boot-direct - Build imported direct BIOS boot image"
	@echo "  boot-run-direct - Build and run direct image in QEMU"
	@echo "  verify  - Verify boot image integrity"
	@echo "  verify OBIELF=1 - Verify and package the boot image through local OBIELF"
	@echo "  obielf-build - Build the sibling ../../obielf Cargo crate"
	@echo "  obielf-install - cargo install --path ../../obielf"
	@echo "  obielf-preview - Show OBIELF formats and package img/mmuko-os.img"
	@echo "  obielf-package-boot - Package boot/build/mmuko-direct.img"
	@echo "  examples - Build/check trident-boot and lt-fileformat examples"
	@echo "  vbox    - Build and run MMUKO-OS boot image in VirtualBox"
	@echo "  clean   - Remove build artifacts"
	@echo "  help    - Show this help"
