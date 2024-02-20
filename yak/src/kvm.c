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

    // Free memory
    vmmap(PML4, (void*)FREE_MEM_BASE, (void*)FREE_MEM_BASE, FREE_MEM_TOP-FREE_MEM_BASE, PTE_READWRITE, PTE_SUPERVISOR, PTE_EXECUTABLE);

    // Trampoline
    vmmap(PML4, (void*)(FREE_MEM_TOP), (void*)(FREE_MEM_TOP), PAGE_SIZE, PTE_READWRITE, PTE_SUPERVISOR, PTE_EXECUTABLE);
}
