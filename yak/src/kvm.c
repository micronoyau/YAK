#include "kalloc.h"
#include "utils.h"
#include "kvm.h"
#include "vm.h"

void* PML4;

void kvminit() {
    /*
     * Discard paging structure needed for the bootloader
     * and create a new (clean) one
     */
    PML4 = kalloc();
    memset(PML4, 0, TABLE_SIZE);

    // Kernel code
    vmmap(PML4, (void*)KERNEL_SEGMENTS, (void*)KERNEL_SEGMENTS, FREE_MEM_BASE-KERNEL_SEGMENTS, PTE_READWRITE, PTE_SUPERVISOR, PTE_EXECUTABLE);

    // Free memory
    vmmap(PML4, (void*)FREE_MEM_BASE, (void*)FREE_MEM_BASE, FREE_MEM_TOP-FREE_MEM_BASE, PTE_READWRITE, PTE_SUPERVISOR, PTE_XD);

    // Trampoline
    // (for now)
    void* trampoline = kalloc();
    memcpy(trampoline, "micronoyau", 10);
    vmmap(PML4, (void*)(FREE_MEM_TOP), trampoline, PAGE_SIZE, PTE_READWRITE, PTE_SUPERVISOR, PTE_EXECUTABLE);

    set_cr3(PML4);
}
