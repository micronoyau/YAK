/*
 * Memory layout :
 * +---------------------------+ <-- MAX_ADDR : 0x20000000 (512 MiB)
 * |        Trampoline         |
 * +---------------------------+ <-- FREE_MEM_TOP : 0x10000000 (256 MiB)
 * |                           |
 * |       Free memory         |
 * |                           |
 * +---------------------------+ <-- FREE_MEM_BASE : 0x500000 (5 MiB)
 * |   Loaded kernel segments  |
 * +---------------------------+ <-- KERNEL_SEGMENTS :  0x400000 (4 MiB)
 * |         ???????           |
 * +---------------------------+
 */

#define KERNEL_SEGMENTS 0x400000
#define FREE_MEM_BASE 0x500000
#define FREE_MEM_TOP 0x10000000
#define MAX_ADDR 0x20000000

#define FRAME_SIZE 0x1000
