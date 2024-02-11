TARGET_DIR=target
BOOTLOADER_DIR=bootloader
KERNEL_DIR=yak

MBR=mbr
SECOND_STAGE=second-stage
SECOND_STAGE_LOADER=loader
SECOND_STAGE_LINKER_SCRIPT=link.ld
BOOTLOADER=bootloader
# Size of entire bootloader (in sector count)
BOOTLOADER_SIZE=10

KERNEL=yak

BOOTABLE_IMAGE=$(TARGET_DIR)/bootable_kernel

all: run

clean:
	rm -rf $(TARGET_DIR)/*

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

#
# Put all the pieces together
#

build: $(TARGET_DIR)/$(BOOTLOADER) $(TARGET_DIR)/$(KERNEL)
	cat $^ > $(BOOTABLE_IMAGE)

#
# Bootloader
#

$(TARGET_DIR)/$(BOOTLOADER): $(TARGET_DIR)/$(MBR).bin $(TARGET_DIR)/$(SECOND_STAGE).bin
	cat $^ > $@

$(TARGET_DIR)/$(MBR).bin: $(TARGET_DIR)
	nasm -f bin \
		-d BOOTLOADER_SIZE=$(BOOTLOADER_SIZE) \
		-o $@ \
		$(BOOTLOADER_DIR)/$(MBR).s

$(TARGET_DIR)/$(SECOND_STAGE).bin: $(TARGET_DIR)/$(SECOND_STAGE).o $(TARGET_DIR)/$(SECOND_STAGE_LOADER).o
	ld -static \
		-T$(BOOTLOADER_DIR)/$(SECOND_STAGE_LINKER_SCRIPT) \
		-nostdlib \
		-nmagic \
		-o $@ \
		$^
	

# Compute size of sections to be added in bootloader and give this information
# to nasm so that the resulting object is of size BOOTLOADER_SIZE as defined in
# $(SECOND_STAGE).s
section_size = $(shell readelf -W -S $(1) \
				| grep " $(2)" \
				| sed 's/\( \)* / /g' \
				| cut -d ' ' -f8)

# memory_elf_size = $(shell readelf -W -l yak \
# 					| grep LOAD \
# 					| sed 's/\( \)* / /g' \
# 					| cut -d ' ' -f7 \
# 					| python -c 'from sys import stdin; print(sum(map(lambda x: int(x, base=16), stdin)))')

$(TARGET_DIR)/$(SECOND_STAGE).o: $(TARGET_DIR) $(TARGET_DIR)/$(SECOND_STAGE_LOADER).o $(TARGET_DIR)/$(KERNEL)
	$(eval LOADER_TEXT_SIZE = $(call section_size,$(TARGET_DIR)/$(SECOND_STAGE_LOADER).o,.text))
	$(eval LOADER_DATA_SIZE = $(call section_size,$(TARGET_DIR)/$(SECOND_STAGE_LOADER).o,.data))
	$(eval LOADER_BSS_SIZE = $(call section_size,$(TARGET_DIR)/$(SECOND_STAGE_LOADER).o,.bss))
	nasm -d LOADER_SIZE=$$((0x$(LOADER_TEXT_SIZE) + 0x$(LOADER_DATA_SIZE) + 0x$(LOADER_BSS_SIZE))) \
		-d BOOTLOADER_SIZE=$(BOOTLOADER_SIZE) \
		-d KERNEL_SIZE=$(shell ls -l $(TARGET_DIR)/$(KERNEL) | cut -d ' ' -f5) \
		-f elf64 \
		-o $@ \
		$(BOOTLOADER_DIR)/$(SECOND_STAGE).s

$(TARGET_DIR)/$(SECOND_STAGE_LOADER).o: $(TARGET_DIR)
	gcc -c \
		-nostdlib \
		-o $@ \
		-Wno-incompatible-library-redeclaration \
		$(BOOTLOADER_DIR)/$(SECOND_STAGE_LOADER).c

#
# Kernel
#

$(TARGET_DIR)/$(KERNEL):
	gcc -o $@ \
		-I$(KERNEL_DIR)/includes/ \
		-nostdlib \
		-Wno-builtin-declaration-mismatch \
		$(KERNEL_DIR)/src/*

#
# Misc
#

$(TARGET_DIR):
	mkdir -p $(TARGET_DIR)
