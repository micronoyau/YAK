/*
 * Kernel virtual memory layout :
 *             ...
 * +---------------------------+ -.
 * |      Kernel stack 1       |   `.
 * +---------------------------+    | --> Mapped in free memory
 * |      Kernel stack 0       |    |
 * +---------------------------+   ,`
 * |         Trampoline        | .`
 * +---------------------------+`<-- FREE_MEM_TOP : 0x40000000 (1 GiB)
 * |                           |
 * |       Free memory         |
 * |                           |
 * +---------------------------+ <-- FREE_MEM_BASE : 0x500000 (5 MiB)
 * |   Loaded kernel segments  |
 * +---------------------------+ <-- KERNEL_SEGMENTS :  0x400000 (4 MiB)
 * |         ???????           |
 * +---------------------------+
 * Note : when entering the kernel, the bootloader gives the kernel its own
 * page table. Thus, the kernel needs to quickly set up this new mapping.
 *
 * From 0x0 to FREE_MEM_TOP : identity mapping.
 * Starting from FREE_MEM_TOP, virtual mapping.
 */

#define KERNEL_SEGMENTS 0x400000
#define FREE_MEM_BASE 0x500000
#define FREE_MEM_TOP 0x20000000 // 512 MiB

void kvminit();
