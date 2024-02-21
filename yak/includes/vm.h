/*
 *  x86 4-level paging structure :
 *            |9 bits|9 bits|9 bits|9 bits| 12 bits
 *  +---------+------+------+------+------+-----------+
 *  | UNUSED  |PML4E |PDPTE | PDE  | PTE  |Page offset|
 *  +---------+------+------+------+------+-----------+
 *  63         47 |   38 |   29 |   20 |   11        0
 *                |      |      |      `-.
 *      .---------'    .-'      `-----.  `-----------.
 *      |              |              |              |
 *      |    ...       |    ...       |    ...       |    ...
 *      |   +----+     |   +----+     |   +----+     |   +----+         ...
 *      `-> |    | --. `-> |    | --. `-> |    | --. `-> |    | --.    |   |
 *          +----+   |     +----+   |     +----+   |     +----+   |--> |xxx|--
 *           ...     |      ...     |      ...     |      ...     |    |xxx|  4
 *          |    |   |     |    |   |     |    |   |     |    |   |    |xxx| KiB
 *          +----+   |     +----+   |     +----+   |     +----+   `--> |xxx|--
 *          |    |   |     |    |   |     |    |   |     |    |        |   |
 *  CR3 --> +----+   `---> +----+   `---> +----+   `---> +----+        +---+
 *           PML4           PDPT            PD             PT           RAM
 *
 *  Page Table Entry :
 *  +-------------------------------------------+
 *  |EXB| 0 |PPN| 0 |G|PAT|D|A|PCD|PWT|U/S|R/W|P|
 *  +-------------------------------------------+
 *     63  52  12   6
 *
 *  Page Directory Entry / Page Directory Pointer Table Entry
 *  / Page Map Level 4 Entry : (pointing to another table base address)
 *  +-----------------------------------+
 *  |EXB| 0 |TBA| 0 |A|PCD|PWT|U/S|R/W|P|
 *  +-----------------------------------+
 *     63  52  12   6
 */

typedef struct PTE { // Page Table Entry
    void* content; // 64 bit PTE
} PTE;
typedef PTE PDE; // Page Directory Entry
typedef PTE PDPTE; // Page Directory Pointer Table Entry
typedef PTE PML4E; // Page Map Level 4 Entry

typedef long PPN; // Physical Page Number
typedef long TBA; // Table Base Address

#define PTE_READONLY 0
#define PTE_READWRITE 1

#define PTE_USER 0
#define PTE_SUPERVISOR  1

// Execute disable
#define PTE_XD 1
#define PTE_EXECUTABLE 0

#define TABLE_SIZE (1 << 12)
#define PAGE_SIZE (1 << 12)
#define MEGAPAGE_SIZE (1 << 21)
#define GIGAPAGE_SIZE (1 << 30)

/*
 * Maps virtual address range from [va] to [va]+[size]
 * to physical address range [pa] -> [pa]+[size].
 * [pml4] is the pml4 address as pointed by CR3.
 * [rw], [us] and [xd] are the R/W U/S and XD flags of page entries in x86.
 * If this virtual address range is already mapped,
 * fails and returns -1.
 */
int vmmap(void* pml4, void* va, void* pa, long size, char rw, char us, long xd);
/*
 * Set CR3 register to setup new page table
 */
void set_cr3(void* addr);
/*
 * Set NXE bit of the EFER register to 1 (enable XD feature)
 */
void enable_efer_nxe();
/*
 * Write a PTE at address [addr]
 */
void new_PTE(void* addr, char rw, char us, long xd, PPN ppn);
/*
 * Write a PDE at address [addr] that references a page table
 */
void new_PDE_PT(void* addr, char rw, char us, long xd, TBA tba);
/*
 * Write a PDE at address [addr] that references a megapage
 */
void new_PDE_MP(void* addr, char rw, char us, long xd, void* pa);
/*
 * Write a PDPTE at address [addr] that references a PD
 */
void new_PDPTE_PD(void* addr, char rw, char us, long xd, TBA tba);
/*
 * Write a PDPTE at address [addr] that references a gigapage
 */
void new_PDPTE_GP(void* addr, char rw, char us, long xd, void* pa);
/*
 * Write a PML4E at address [addr] that points to a PDPT
 */
void new_PML4E(void* addr, char rw, char us, long xd, TBA tba);
