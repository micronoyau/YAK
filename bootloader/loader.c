/*
 * ELF loader to load kernel in memory.
 * Extremely simple and full of flaws, but designed to work with this kernel only.
 * + first loads entire kernel file in memory at address [KERNEL_FILE_ADDR]
 * + then loads loadable segments in memory (at physical addresses)
 * Structure of bootable image :
 * +----------------------+
 * +          MBR         + 512 B
 * +----------------------+
 * | 2nd stage bootloader |`-,
 * |      (assembly)      |  |
 * +----------------------+  |
 * |        padding       |  | --> BOOTLOADER_SIZE, defined in second-stage.s
 * +----------------------+  |
 * |       this file      |  |
 * |       (C code)       | .`
 * +----------------------+`
 * |      Kernel elf      | KERNEL_SIZE
 * +----------------------+
 */

// Where to load the file from disk (not to be confused with loaded segments,
// whose location is defined entirely by the ELF PHT)
#define KERNEL_FILE_ADDR 0x300000
#define PT_LOAD 0x01

extern void load_sectors(int offset_disk, int count, void* addr);

typedef struct {
    unsigned char e_ident[16];
    unsigned char e_type[2];
    unsigned char e_machine[2];
    unsigned char e_version[4];
    unsigned char e_entry[8];
    unsigned char e_phoff[8];
    unsigned char e_shoff[8];
    unsigned char e_flags[4];
    unsigned char e_ehsize[2];
    unsigned char e_phentsize[2];
    unsigned char e_phnum[2];
    unsigned char e_shentsize[2];
    unsigned char e_shnum[2];
    unsigned char e_shstrndx[2];
} Elf64_Ehdr;

typedef struct {
    unsigned char p_type[4];
    unsigned char p_flags[4];
    unsigned char p_offset[8];
    unsigned char p_vaddr[8];
    unsigned char p_paddr[8];
    unsigned char p_filesz[8];
    unsigned char p_memsz[8];
    unsigned char p_align[8];
} Elf64_Phdr;

long entry_to_long(char* entry, int size) {
    long res = 0;
    for (int i=size-1; i>=0; i--){
        res <<= 8;
        // Compiler translates as movsx, but we dont want
        // the sign extension.
        res |= (0xff & entry[i]);
    }
    return res;
}

void memcpy(void* dst_, void* src_, long sz) {
    // 64 bit machine : can copy 8 by 8
    long* src = (long*) src_;
    long* dst = (long*) dst_;
    long i;
    for (i=0; i<sz>>3; i++) {
        *(dst+i) = *(src+i);
    }
    i*=8;

    // Remaining bytes : copy byte per byte
    char* src2 = (char*) src;
    char* dst2 = (char*) dst;
    for (int j=0; j<sz%8; j++) {
        *(dst2+i+j) = *(src2+i+j);
    }
}

int load_segment(Elf64_Phdr* phdr) {
    /*
     * Loads an entire segment in memory at physical address phdr->p_p_addr
     */
    void* offset = (void*) (KERNEL_FILE_ADDR + entry_to_long((char*)phdr->p_offset, 8));
    void* paddr = (void*) entry_to_long((char*)phdr->p_paddr, 8);
    long memsz = entry_to_long((char*)phdr->p_memsz, 8);
    long filesz = entry_to_long((char*)phdr->p_filesz, 8);

    // Check that elf header is not malformed.
    if (memsz < filesz) {
        return 1;
    }

    memcpy(paddr, offset, filesz);
    return 0;
}

void* load_kernel(int bootloader_size, int kernel_size) {
    /*
     * [bootloader_size] : size of bootloader, in sector counts (should be padded).
     * [kernel_size] : size of kernel, in sector counts.
     * Loads kernel in memory :
     * + loads binary file in memory
     * + fetches elf header
     * + loads loadable segments at specified physical addresses
     * + returns entrypoint address
     * If an error occurs, returns 0.
     */
    load_sectors(bootloader_size, kernel_size, (void*)KERNEL_FILE_ADDR);
    Elf64_Ehdr* header = (Elf64_Ehdr*)KERNEL_FILE_ADDR;

    void* pht_addr = (void*)(KERNEL_FILE_ADDR + entry_to_long((char*)header->e_phoff, 8));
    int ph_num = entry_to_long((char*)header->e_phnum, 2);
    int ph_entsize = entry_to_long((char*)header->e_phentsize, 2);

    for (void* ph=pht_addr; ph<pht_addr + ph_num*ph_entsize; ph+=ph_entsize) {
        Elf64_Phdr* phdr = ph;
        if(phdr->p_type[0] == PT_LOAD) {
            if (load_segment(phdr)) {
                return 0;
            }
        }
    }

    return (void*) entry_to_long((char*)header->e_entry, 8);
}
