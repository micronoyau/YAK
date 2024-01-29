TARGET_DIR=target
BUILD_DIR=$(TARGET_DIR)/tmp
BOOTLOADER_DIR=bootloader
PREPROC_DIR=preprocessor
KERNEL_DIR=yak

MBR=mbr
SECOND_STAGE=second-stage

KERNEL_SEGMENTS=$(BUILD_DIR)/kernel_segments.bin
KERNEL_RUST_OUT=$(KERNEL_DIR)/target/x86_64-unkown-yak/debug/yak

NASM_PREPROC=$(BUILD_DIR)/nasm-preproc.s
BOOTABLE_IMAGE=$(TARGET_DIR)/bootable_kernel
BOOTLOADER_IMAGE=$(TARGET_DIR)/bootloader

all: run

clean:
	rm -rf $(TARGET_DIR)/*
	cd $(KERNEL_DIR) && cargo clean

run: build
	qemu-system-x86_64 -drive file=$(BOOTABLE_IMAGE),format=raw

#
# Debugging using QEMU
#

debug: build
	qemu-system-x86_64 -drive file=$(BOOTABLE_IMAGE),format=raw -S -gdb tcp::1234 &
	gdb $(OUT) \
		-ex "target remote localhost:1234" \
		-ex "set architecture i8086" \
		-ex "b *0x7c00" \
		-ex "c" \

debug_bootloader: bootloader
	qemu-system-x86_64 -drive file=$(BOOTLOADER_IMAGE),format=raw -S -gdb tcp::1234 &
	gdb $(OUT) \
		-ex "target remote localhost:1234" \
		-ex "set architecture i8086" \
		-ex "b *0x7c00" \
		-ex "c" \

#
# Put all the pieces together
#

build: $(TARGET_DIR)/$(MBR).bin $(TARGET_DIR)/$(SECOND_STAGE).bin $(KERNEL_SEGMENTS)
	cat $^ > $(BOOTABLE_IMAGE)

bootloader: $(TARGET_DIR)/$(MBR).bin $(TARGET_DIR)/$(SECOND_STAGE).bin
	cat $^ > $(BOOTLOADER_IMAGE)

$(TARGET_DIR):
	mkdir -p $(TARGET_DIR)

$(BUILD_DIR): $(TARGET_DIR)
	mkdir -p $(BUILD_DIR)

#
# Bootloader
#

$(TARGET_DIR)/$(MBR).bin: $(TARGET_DIR)
	nasm -f bin $(BOOTLOADER_DIR)/$(MBR).s -o $@

$(TARGET_DIR)/$(SECOND_STAGE).bin: $(KERNEL_RUST_OUT) $(KERNEL_SEGMENTS)
	cat $(NASM_PREPROC) $(BOOTLOADER_DIR)/$(SECOND_STAGE).s > $(NASM_PREPROC).2
	nasm -f bin $(NASM_PREPROC).2 -o $@

#
# Kernel
#

$(KERNEL_SEGMENTS): $(KERNEL_RUST_OUT) $(BUILD_DIR)
	cd $(PREPROC_DIR) && cargo run ../$(KERNEL_RUST_OUT) ../$(KERNEL_SEGMENTS) ../$(NASM_PREPROC)

$(KERNEL_RUST_OUT):
	cd $(KERNEL_DIR) && cargo build
