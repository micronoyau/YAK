#include "vm.h"
#include "kalloc.h"
#include "utils.h"

#define PML4E_SHIFT 39
#define PML4E_MASK ((0b111111111l) << PML4E_SHIFT)
#define PDPTE_SHIFT 30
#define PDPTE_MASK ((0b111111111l) << PDPTE_SHIFT)
#define PDE_SHIFT 21
#define PDE_MASK ((0b111111111l) << PDE_SHIFT)
#define PTE_SHIFT 12
#define PTE_MASK ((0b111111111l) << PTE_SHIFT)

int is_intermediate_entry(void* entry) {
    /*
     * Is this PML4E, PDPTE or PDE an intermediate entry ?
     */
    // Check PS
    return (*(long*)entry & 0x100) >> 8 == 0;
}

void* get_next_tba(void* entry) {
    /*
     * Assuming this PML4E, PDPTE or PDE is an intermediate entry,
     * returns the address of the next table (TBA)
     */
    return (void*) (((*(long*)entry >> 12) & 0xffffffff) << 12);
}

int get_va_table_index(void* va, long mask, long shift) {
    /*
     * Get index of address [va] in PT / PD / PDPT / PML4 [table].
     */
    return 8*(((long)va & mask) >> shift);
}

int check_vmmap(void* pml4, void* va, void* pa, long size) {
    /*
     * Check that the asked mapping is valid. 0 on success, -1 on failure.
     * Assuming we can't address more than 512 GiB of RAM, such that the PML4 entry
     * is always at index 0 (bits 39 to 47 are always null in virtual address)
     */
    if (get_va_table_index(va, PML4E_MASK, PML4E_SHIFT) != 0
        || get_va_table_index(va+size, PML4E_MASK, PML4E_SHIFT) != 0)
        return -1;

    void* pml4e = pml4;

    // Is the PML4 entry not present ? -> The whole paging structure is ours !
    if ((*(long*)pml4e & 1) == 0)
        return 0;

    while (size != 0) {
        void* pdpt = get_next_tba(pml4e);
        void* pdpte = pdpt + get_va_table_index(va, PDPTE_MASK, PDPTE_SHIFT);

        // Is this PDPT entry absent ?
        if ((*(long*)pdpte & 1) == 0) {
            // Do we need a gigapage ?
            if (size >= GIGAPAGE_SIZE
                && (long)va % GIGAPAGE_SIZE == 0
                && (long)pa % GIGAPAGE_SIZE == 0) {
                va += GIGAPAGE_SIZE;
                pa += GIGAPAGE_SIZE;
                size -= GIGAPAGE_SIZE;
                continue;
            }

            // Else, we need less, so it should be enough
            return 0;

        // We need a gigapage but the matching PDPT entry already exists
        } else if (size >= GIGAPAGE_SIZE
                   && (long)va % GIGAPAGE_SIZE == 0
                   && (long)pa % GIGAPAGE_SIZE == 0) {
            return -1;

        // We need smaller than a gigapage but the matching PDPT entry points to a gigapage
        } else if (!is_intermediate_entry(pdpte)) {
            return -1;
        }

        void* pd = get_next_tba(pdpte);
        void* pde = pd + get_va_table_index(va, PDE_MASK, PDE_SHIFT);

        // Is this PD entry absent ?
        if ((*(long*)pde & 1) == 0) {
            // Do we need a megapage ?
            if (size >= MEGAPAGE_SIZE
                && (long)va % MEGAPAGE_SIZE == 0
                && (long)pa % MEGAPAGE_SIZE == 0) {
                va += MEGAPAGE_SIZE;
                pa += MEGAPAGE_SIZE;
                size -= MEGAPAGE_SIZE;
                continue;
            }

            // Else, we need less, so it should be enough
            return 0;

        // We need a megapage but the matching PD entry already exists
        } else if (size >= MEGAPAGE_SIZE
                   && (long)va % MEGAPAGE_SIZE == 0
                   && (long)pa % MEGAPAGE_SIZE == 0) {
            return -1;

        // We need smaller than a megapage but the matching PD entry points to a megapage
        } else if (!is_intermediate_entry(pde)) {
            return -1;
        }

        void* pt = get_next_tba(pde);
        void* pte = pt + get_va_table_index(va, PTE_MASK, PTE_SHIFT);

        // Is this PT entry already present ?
        if ((*(long*)pte & 1) == 1)
            return -1;

        va += PAGE_SIZE;
        pa += PAGE_SIZE;
        size -= PAGE_SIZE;
    }

    return 0;
}

int vmmap_core(void* pml4, void* va, void* pa, long size, char rw, char us, long xd) {
    /*
     * Core of vmmap function (this is vmmap without the preliminary test)
     */
    if (size == 0) {
        return 0;
    }

    void* pml4e = pml4; // We use only the first entry

    // Is this PML4 entry absent ? If yes, create it.
    if ((*(long*)pml4e & 1) == 0) {
        void* pdpt = kalloc();
        memset(pdpt, 0, TABLE_SIZE);
        new_PML4E(pml4e, rw, us, xd, (TBA)pdpt);
    }

    void* pdpt = get_next_tba(pml4e);
    void* pdpte = pdpt + get_va_table_index(va, PDPTE_MASK, PDPTE_SHIFT);

    // Is this PDPT entry absent ? If yes, create it
    if ((*(long*)pdpte & 1) == 0) {
        // We dont need a gigapage
        if (size < GIGAPAGE_SIZE
            || (long)va % GIGAPAGE_SIZE != 0
            || (long)pa % GIGAPAGE_SIZE != 0) {
            void* pd = kalloc();
            memset(pd, 0, TABLE_SIZE);
            new_PDPTE_PD(pdpte, rw, us, xd, (TBA)pd);
        // Allocate gigapage and map the remaining size
        } else {
            new_PDPTE_GP(pdpte, rw, us, xd, pa);
            return vmmap_core(pml4,
                              (void*)((long)va+GIGAPAGE_SIZE),
                              (void*)((long)pa+GIGAPAGE_SIZE),
                              size-GIGAPAGE_SIZE, rw, us, xd);
        }
    }

    void* pd = get_next_tba(pdpte);
    void* pde = pd + get_va_table_index(va, PDE_MASK, PDE_SHIFT);

    // Is this PD entry absent ? If yes, create it
    if ((*(long*)pde & 1) == 0) {
        if (size < MEGAPAGE_SIZE
            || (long)va % MEGAPAGE_SIZE != 0
            || (long)pa % MEGAPAGE_SIZE != 0) {
            void* pt = kalloc();
            memset(pt, 0, TABLE_SIZE);
            new_PDE_PT(pde, rw, us, xd, (TBA)pt);
        // Allocate megapage and map the remaining size
        } else {
            new_PDE_MP(pde, rw, us, xd, pa);
            return vmmap_core(pml4,
                              (void*)((long)va+MEGAPAGE_SIZE),
                              (void*)((long)pa+MEGAPAGE_SIZE),
                              size-MEGAPAGE_SIZE, rw, us, xd);
        }
    }

    void* pt = get_next_tba(pde);
    void* pte = pt + get_va_table_index(va, PTE_MASK, PTE_SHIFT);

    // At this point, the PT entry should not be present
    if ((*(long*)pte & 1) == 0) {
        // Add a new 4 KiB page
        new_PTE(pte, rw, us, xd, (long)pa);
        return vmmap_core(pml4,
                          (void*)((long)va+PAGE_SIZE),
                          (void*)((long)pa+PAGE_SIZE),
                          size-PAGE_SIZE, rw, us, xd);
    // Should not happen
    } else {
        return -1;
    }

    return 0;
}

int vmmap(void* pml4, void* va, void* pa, long size, char rw, char us, long xd) {
    if (check_vmmap(pml4, va, pa, size) != 0)
        return -1;

    return vmmap_core(pml4, va, pa, size, rw, us, xd);
}

void set_cr3(void* addr) {
    asm volatile("mfence\n\t"
                 "mov %0, %%rax\n\t"
                 "mov %%rax, %%cr3\n\t"
                 "mfence"
                 :
                 : "r" (addr));
}

void enable_efer_nxe() {
    asm volatile("mov $0xc0000080, %rcx\n\t"
                 "rdmsr\n\t"
                 "or $0x800, %rax\n\t"
                 "wrmsr\n\t");
}

void new_PTE(void* addr, char rw, char us, long xd, PPN ppn) {
    ppn >>= 12; // Write only bits 51 to 12 of physical address

    *((long*)addr) = 0; // Set PTE to 0
    char* addr_ = (char*) addr;

    // Hardcoded values : P = 1, PWT = 0, PCD = 0, A = 0, D = 0, PAT = 0, G = 0
    (*addr_) |= (1<<0);
    (*addr_) |= (rw<<1);
    (*addr_) |= (us<<2);

    // First 4 bits (bits 12 to 15)
    addr_ += 1;
    (*addr_) |= (ppn & 0xf) << 4;
    ppn >>= 4;

    // Remaining 36 bits
    addr_ += 1;
    (*addr_) |= (ppn & 0xff);
    ppn >>= 8;
    addr_ += 1;
    (*addr_) |= (ppn & 0xff);
    ppn >>= 8;
    addr_ += 1;
    (*addr_) |= (ppn & 0xff);
    ppn >>= 8;
    addr_ += 1;
    (*addr_) |= (ppn & 0xff);
    ppn >>= 8;
    addr_ += 1;
    (*addr_) |= (ppn & 0xf);

    // Last bit : execute disable
    *(long*)addr |= (xd<<63);
}

void new_PDE_PT(void* addr, char rw, char us, long xd, TBA tba) {
    new_PTE(addr, rw, us, xd, tba);
}

void new_PDPTE_PD(void* addr, char rw, char us, long xd, TBA tba) {
    new_PTE(addr, rw, us, xd, tba);
}

void new_PML4E(void* addr, char rw, char us, long xd, TBA tba) {
    new_PTE(addr, rw, us, xd, tba);
}

void new_PDE_MP(void* addr, char rw, char us, long xd, void* pa) {
    long pa_ = (long)pa;
    // Clear lsb
    pa_ >>= 21;
    pa_ <<= 21;
    new_PTE(addr, rw, us, xd, pa_);
    *(long*)addr ^= 0b10000000;
}

void new_PDPTE_GP(void* addr, char rw, char us, long xd, void* pa) {
    long pa_ = (long)pa;
    // Clear lsb
    pa_ >>= 30;
    pa_ <<= 30;
    new_PTE(addr, rw, us, xd, pa_);
    *(long*)addr ^= 0b10000000;
}
