/*
 * Kernel virtual memory layout :
 *             ...
 * +---------------------------+ -.
 * |      Kernel stack 1       |   `.
 * +---------------------------+    | --> Mapped in free memory
 * |      Kernel stack 0       |    |
 * +---------------------------+   ,`
 * |         Trampoline        | .`
 * +---------------------------+`<-- FREE_MEM_TOP : 0x20000000 (512 MiB)
 * |                           |
 * |       Free memory         |
 * |                           |
 * +---------------------------+ <-- KERNEL_TOP (page-aligned)
 * |           .bss            | RW  `.
 * +---------------------------+       `.
 * |           .data           | RW     |
 * +---------------------------+        | --> Kernel segments loaded in memory
 * |          .rodata          | R      |
 * +---------------------------+       ,`
 * |           .text           | RX  .`
 * +---------------------------+ <-- KERNEL_BASE (page-aligned)
 * |         ???????           |
 * +---------------------------+
 * Note : when entering the kernel, the bootloader gives the kernel its own
 * page table. Thus, the kernel needs to quickly set up this new mapping.
 *
 * From 0x0 to FREE_MEM_TOP : identity mapping.
 * Starting from FREE_MEM_TOP, virtual mapping.
 */

#define KERNEL_STACK_SIZE 0x1000
#define FREE_MEM_TOP 0x20000000 // 512 MiB

// Set by linker
extern char KERNEL_BASE[];
extern char KERNEL_TOP[];
extern char RODATA_SECTION_START[];
extern char DATA_SECTION_START[];
extern char BSS_SECTION_START[];

void kvminit();
