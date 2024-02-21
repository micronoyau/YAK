; Dual-stage bootlader that simply :
; 0) Checks if A20 is enabled. If not, hangs forever
; 1) Loads a naive GDT with 2 segment descriptors for code and [data,
; stack, extra] in ring 0. Overlapping segments : they both have:
;   + Base = 0
;   + Limit = 0xfffff in steps of 4096 B, so segments can access the
;     whole 32 bit memory.
; There is also another segment descriptor to use with long mode.
; 2) Switches to protected mode
; 3) Sets up a 1 MB stack at first MB after BIOS memory (0x200000 growing to 0x100000)
; 4) Loads a level-4 paging system in memory
; 5) Switches to long mode
; 6) Loads kernel (stub kernel for now)

; Doc :
; + https://wiki.osdev.org/X86-64
; + https://wiki.osdev.org/Bootloader
; + http://www.osdever.net/tutorials/view/the-world-of-protected-mode
; + https://wiki.osdev.org/Protected_mode
; + https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)
; + https://wiki.osdev.org/Memory_Map_(x86)
; + https://www.youtube.com/watch?v=FzvDGDdtzws
; + https://www.iaik.tugraz.at/teaching/materials/os/tutorials/paging-on-intel-x86-64/
; + https://os.phil-opp.com/paging-introduction/
; + Intel 64 developper manual

; Defined at compile time :
; %define LOADER_SIZE ???
; %define BOOTLOADER_SIZE ???
; %define KERNEL_SIZE ???

; Has to be consistent
%define PDPT_ADDR 0x200000
%define STACK_ADDR 0x200000

extern load_kernel
global load_sectors
global _start

[BITS 16]

; MBR loads the second stage bootloader at 0x7e00
; org 0x7e00

section .boot
    jmp _start

    ; Args : string
    strlen:
        push bp
        mov bp, sp
        push si

        xor cx, cx
        mov si, [bp+0x4]

        strlen_loop:
            mov dl, byte [ds:si] ; ds should be 0
            test dl, dl
            jz strlen_end
            inc cx
            inc si
            jmp strlen_loop

        strlen_end:
            mov ax, cx
            pop si
            pop bp
            ret 2


    ; Clears screen and displays string using BIOS interrupts
    ; Args : string
    print_wait_bios:
        push bp
        mov bp, sp

        ; Clear screen
        mov bp, [bp+0x4]
        mov ah, 0x07    ; Scroll down window
        mov al, 0       ; Entire window
        mov bh, 0x0f    ; Attributes (colour)
        xor cx, cx      ; Row | Column of top left corner
        mov dx, 0x2050  ; Row | Column of bottom right corner (arbitrary here)
        int 0x10

        ; Display string
        ; First compute length of string
        mov bp, sp
        mov ax, [bp+0x4]
        push ax
        call strlen
        mov cx, ax

        mov bp, [bp+0x4] ; The string to display
        mov ah, 0x13    ; Display string
        mov al, 1       ; Update cursor after writing
        mov bh, 0       ; Page number
        mov bl, 0x0f    ; Attributes (color)
        mov dx, 0       ; Row | Column
        int 0x10

        ; Wait roughly 1 second --- less for debug
        ; mov ah, 0x86
        mov ah, 0x1
        mov cx, 0x10
        xor dx, dx
        int 0x15

        pop bp
        ret 2


    ; Test if A20 is enabled. Returns 0 if it is, else 1.
    test_a20:
        push bp
        mov bp, sp
        push di
        push si
        push ds
        push es

        ; Set data segment register to zero
        xor ax, ax
        mov ds, ax

        ; Set extra segment register to 0xffff
        not ax
        mov es, ax

        mov si, 0x7c00 + 510
        mov ax, word [ds:si] ; Should fetch magic number 0xaa55
        mov di, 0x7c00 + 0x100000 + 510 - 0xffff0
        mov bx, word [es:di] ; Is it still the magic number ?
        pop es ; Restore es (we will need it for int 0x13)

        cmp ax, bx
        je print_A20_disabled

        ; Sucess
        push str_A20_enabled
        call print_wait_bios
        xor ax, ax
        jmp test_a20_end

        ; Fail
        print_A20_disabled:
            push str_A20_disabled
            call print_wait_bios
            inc ax

        test_a20_end:
            pop ds
            pop si
            pop di
            pop bp
            ret


    ; Setup a GDT for code and data
    setup_gdt:
        lgdt [gdtr]
        ret


    [BITS 32]
    ; Stack : 0x1fffff --> 0x100000 (1 MiB)
    setup_stack:
        ; Save return address in eax
        pop eax
        mov esp, STACK_ADDR
        mov ebp, esp
        push eax
        ret


    setup_page_tables:
        ; Paging structure :
        ;           |9 bits|9 bits|9 bits|9 bits| 12 bits
        ; +---------+------+------+------+------+-----------+
        ; | UNUSED  |PML4E |PDPTE | PDE  | PTE  |Page offset|
        ; +---------+------+------+------+------+-----------+
        ; 63         47 |   38 |   29 |   20 |   11        0
        ;               |      |      |      `-.
        ;     .---------'    .-'      `-----.  `-----------.
        ;     |              |              |              |
        ;     |    ...       |    ...       |    ...       |    ...
        ;     |   +----+     |   +----+     |   +----+     |   +----+         ...
        ;     `-> |    | --. `-> |    | --. `-> |    | --. `-> |    | --.    |   |
        ;         +----+   |     +----+   |     +----+   |     +----+   |--> |xxx|--
        ;          ...     |      ...     |      ...     |      ...     |    |xxx|  4
        ;         |    |   |     |    |   |     |    |   |     |    |   |    |xxx| KiB
        ;         +----+   |     +----+   |     +----+   |     +----+   `--> |xxx|--
        ;         |    |   |     |    |   |     |    |   |     |    |        |   |
        ; CR3 --> +----+   `---> +----+   `---> +----+   `---> +----+        +---+
        ;          PML4           PDPT            PD             PT           RAM
        ;
        ; Page Table Entry :
        ; +-------------------------------------------+
        ; |EXB| 0 |PPN| 0 |G|PAT|D|A|PCD|PWT|U/S|R/W|P|
        ; +-------------------------------------------+
        ;    63  52  12   6
        ;
        ; Page Directory Entry / Page Directory Pointer Table Entry
        ; / Page Map Level 4 Entry :
        ; +-----------------------------------+
        ; |EXB| 0 |TBA| 0 |A|PCD|PWT|U/S|R/W|P|
        ; +-----------------------------------+
        ;    63  52  12   6

        ; Identity-paging first 1 GiB (should be enough for now)
        ; PDPT
        mov edi, PDPT_ADDR
        xor eax, eax
        xor ebx, ebx
        ; Gigapage, not user-accessible, writeeable, present
        mov al, 0b10000111
        mov [edi], eax
        mov [edi+4], ebx

        ; PML4 4 KiB further
        xor eax, eax
        mov al, 0b00000011
        or eax, edi
        add edi, 0x1000
        mov [edi], eax
        mov [edi+4], ebx

        ; Set PML4 address in CR3
        mov eax, edi
        mov cr3, eax

        ret


    [BITS 64]
    ; Uses ATA PIO mode
    ; Load [rsi] sectors on disk at sector offset [rdi] on disk (1 sector = 512 MiB)
    ; at address [rdx]
    ; load_sectors(int offset_disk, int count, void* addr)
    load_sectors:
        push rbp
        mov rbp, rsp
        push rdx ; Save address

        ; Write number of sectors to read to port 0x1f2 (sector count register)
        mov eax, esi
        mov dx, 0x1f2
        out dx, eax

        ; LBA addressing
        inc dx
        mov rax, rdi
        out dx, al
        inc dx
        shr rax, 8
        out dx, al
        inc dx
        shr rax, 8
        out dx, al

        ; Choose master drive (0x1f6)
        inc dx
        mov ax, 0x40
        out dx, ax

        ; READ SECTORS command (0x1f7)
        inc dx
        mov ax, 0x20
        out dx, ax

        pop rax
        mov edi, eax ; Load address
        xor ebx, ebx ; Written sectors so far

        ; Read all sectors
        load_sectors_loop:
            or dl, 0x7
            ; Wait for busy flag to be cleared
            load_sectors_wait:
                in al, dx
                test al, 0x80
                jnz load_sectors_wait

            and dl, 0xf0 ; Read from data port
            ; Load one sector (256 words)
            mov rcx, 0x100
            rep insw

            inc ebx

            cmp ebx, esi
            jb load_sectors_loop

        pop rbp
        ret


    [BITS 16]
    ; Main procedure
    _start:
        push dx ; Save drive number

        push str_welcome
        call print_wait_bios

        call test_a20
        test ax, ax
        jnz loop_main

        push str_setting_up_gdt
        call print_wait_bios
        cli ; Disable interrupts
        call setup_gdt
        sti ; Enable again

        ; Set cr0 protected mode bit to 1
        push str_launching_protected_mode
        call print_wait_bios
        cli
        mov eax, cr0
        or eax, 1
        mov cr0, eax

        ; Jumps to an adress using the newly defined code segment descriptor -> sets cs
        ; Which in turns enables protected-mode segmented adressing using GDT
        jmp 0x08:main_32

        [BITS 32]
        main_32:
            ; Setup data segment and stack segment
            mov eax, 0x10
            mov ds, ax
            mov ss, ax

        pop dx ; Keep drive number (might need it later)
        call setup_stack
        push edx

        call setup_page_tables

        ; Set PAE (Physical Address Extension)
        mov eax, cr4
        or eax, (1<<5)
        mov cr4, eax

        ; Set LME (Long Mode Enable)
        mov ecx, 0xc0000080
        rdmsr
        or eax, 0x100
        wrmsr

        ; Enable paging
        xor ebx, ebx
        inc ebx
        shl ebx, 31
        mov eax, cr0
        or eax, ebx
        mov cr0, eax

        ; Update code segment selector and GDT
        ; (setting DB=0 and L=1)
        mov eax, [gdt+0xc]
        or eax, 0x600000
        mov [gdt+0xc], eax

        ; Finally, reload CS and perform long jump
        jmp 0x8:main_64

        [BITS 64]
        main_64:
        mov rdi, BOOTLOADER_SIZE
        mov rsi, KERNEL_SIZE
        shr rsi, 9
        inc rsi
        call load_kernel

        ; On failure, loops indifinetely
        test rax, rax
        jz loop_main

        ; Jump to kernel entrypoint
        jmp rax

        loop_main:
            jmp loop_main

    ; Data
    str_welcome:
        db "Welcome to the best bootloader ever, my friend!", 0

    str_A20_enabled:
        db "A20 line is enabled", 0

    str_A20_disabled:
        db "A20 line is disabled :(", 0

    str_setting_up_gdt:
        db "Setting up GDT...", 0

    str_launching_protected_mode:
        db "Launching protected mode and leaving BIOS ...", 0

    ; Global Descriptor Table content
    gdt:
        ; Null segment descriptor
        dq 0

        ; Code segment descriptor
        dw 0xffff ; Limit[15:0]
        dw 0 ; Base[0:15]
        db 0 ; Base[16:23]
        db 0b10011011 ; P=1 DPL=00 (kernel) S=1 E=1 C=0 R=1 A=1
        db 0b11001111 ; G=1 DB=1 L=0 reserved=0 Limit[19:16] = 0xf
        db 0 ; Base[24:31]

        ; Data segment descriptor
        dw 0xffff ; Limit[15:0]
        dw 0 ; Base[0:15]
        db 0 ; Base[16:23]
        db 0b10010011 ; P=1 DPL=00 (kernel) S=1 E=0 D=0 W=1 A=1
        db 0b11001111 ; G=1 DB=1 L=0 reserved=0 Limit[19:16] = 0xf
        db 0 ; Base[24:31]

        gdt_end:

    ; Data to be loaded in GDTR (base and size of GDT)
    gdtr:
        dw gdt_end - gdt ; Size
        dd gdt ; Base

    ; Fill with junk to be aligned
    boot_end:
        times BOOTLOADER_SIZE*0x200-($-$$)-LOADER_SIZE-512 db 0x00

