OUTPUT_FORMAT("elf64-x86-64")
SECTIONS
{
    /* Kernel virtual addresses start at 4 MiB */
    . = 0x400000;
    PROVIDE(KERNEL_BASE = .);

    .text : {
        *(.text)
    }

    . = ALIGN(0x1000);

    PROVIDE(RODATA_SECTION_START = .);
    .rodata : {
        *(.rodata .rodata.*)
    }

    . = ALIGN(0x1000);

    PROVIDE(DATA_SECTION_START = .);
    .data : {
        *(.data .data.*)
    }

    . = ALIGN(0x10);

    PROVIDE(BSS_SECTION_START = .);
    .bss : {
        *(.bss .bss.*)
    }

    . = ALIGN(0x1000);

    PROVIDE(KERNEL_TOP = .);
}
