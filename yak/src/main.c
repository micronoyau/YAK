#include "utils.h"
#include "kalloc.h"
#include "kvm.h"

// Kernel stack in .bss section, should be NX
char stack[KERNEL_STACK_SIZE];

void kernel_main() {
    kinit();
    kvminit();
    while(1) { }
}
