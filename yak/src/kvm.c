#include "kalloc.h"
#include "utils.h"
#include "kvm.h"
#include "vm.h"

void* PML4; // Page Map Level 4 address (content of CR3 register)

void kvminit() {
    /*
     * Discard paging structure needed for the bootloader
     * and create a new (clean) one
     */
    PML4 = kalloc();
    memset(PML4, 0, TABLE_SIZE);

    // Kernel code (.text)
    vmmap(PML4, KERNEL_BASE, KERNEL_BASE, RODATA_SECTION_START-KERNEL_BASE, PTE_READONLY, PTE_SUPERVISOR, PTE_EXECUTABLE);
    // .rodata : R
    vmmap(PML4, RODATA_SECTION_START, RODATA_SECTION_START, DATA_SECTION_START-RODATA_SECTION_START, PTE_READONLY, PTE_SUPERVISOR, PTE_XD);
    // .data : RW
    vmmap(PML4, DATA_SECTION_START, DATA_SECTION_START, BSS_SECTION_START-DATA_SECTION_START, PTE_READWRITE, PTE_SUPERVISOR, PTE_XD);
    // .bss : RW
    vmmap(PML4, BSS_SECTION_START, BSS_SECTION_START, KERNEL_TOP-BSS_SECTION_START, PTE_READWRITE, PTE_SUPERVISOR, PTE_XD);

    // Free memory
    vmmap(PML4, KERNEL_TOP, KERNEL_TOP, (long)FREE_MEM_TOP-(long)KERNEL_TOP, PTE_READWRITE, PTE_SUPERVISOR, PTE_XD);

    // Trampoline
    // (for now)
    void* trampoline = kalloc();
    memcpy(trampoline, "micronoyau", 10);
    vmmap(PML4, (void*)(FREE_MEM_TOP), trampoline, PAGE_SIZE, PTE_READONLY, PTE_SUPERVISOR, PTE_EXECUTABLE);

    enable_efer_nxe();
    set_cr3(PML4);
}
