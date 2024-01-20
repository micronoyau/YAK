TARGET_DIR=target
MBR=mbr
KERNEL=kernel
ENTRYPOINT=0x7e00
KERNEL_DIR=yak
# KERNEL_RUST_OUT=$(KERNEL_DIR)/target/x86_64-unkown-yak/debug/yak
KERNEL_RUST_OUT=tmp/kernel.o
BOOTABLE_IMAGE=$(TARGET_DIR)/bootable_kernel

all: run

clean:
	rm -rf target

run: build
	qemu-system-x86_64 -drive file=$(BOOTABLE_IMAGE),format=raw

# Debugging using QEMU
debug: build
	qemu-system-x86_64 -drive file=$(BOOTABLE_IMAGE),format=raw -S -gdb tcp::1234 &
	gdb $(OUT) \
		-ex "target remote localhost:1234" \
		-ex "set architecture i8086" \
		-ex "b *0x7c00" \
		-ex "c" \

# Since the bootloader simply jumps to the next sector,
# simply concatenate master boot record with kernel binary file
build: $(TARGET_DIR)/$(MBR).bin $(TARGET_DIR)/$(KERNEL).bin
	cat $^ > $(BOOTABLE_IMAGE)

$(TARGET_DIR):
	mkdir -p $(TARGET_DIR)

# MBR must be a 512-bytes binary file
$(TARGET_DIR)/$(MBR).bin: $(TARGET_DIR)
	nasm -f bin $(MBR).s -o $@

# Link kernel entry and kernel core into a binary file such that the only
# instruction in kernel-entry is at the kernel entrypoint address mentionned in MBR
$(TARGET_DIR)/$(KERNEL).bin: $(TARGET_DIR)/$(KERNEL)-entry.o $(KERNEL_RUST_OUT)
	ld -o $@ -Ttext $(ENTRYPOINT) --oformat binary $^

$(TARGET_DIR)/$(KERNEL)-entry.o: $(KERNEL)-entry.s
	nasm $< -f elf64 -o $@

$(KERNEL_RUST_OUT):
	cd $(KERNEL_DIR) && cargo build
