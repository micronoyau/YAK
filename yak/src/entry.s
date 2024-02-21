extern stack
extern kernel_main

global _start

section .text
_start:
    mov rsp, stack
    add rsp, 0x1000 ; Should be consistent with C code (KERNEL_STACK_SIZE)
    mov rbp, rsp
    call kernel_main
