; Single-stage bootlader that simply :
; + Loads kernel (stub kernel for now)
; + Checks A20 is enabled
; + Loads a trivial GDT with a code segment descriptor and a data segment descriptor.
;   For now, code and data are in the same place (I'll see later how to properly organize segments)
;  + Switches to protected mode

; Doc :
; + https://wiki.osdev.org/Bootloader
; + http://www.osdever.net/tutorials/view/the-world-of-protected-mode
; + https://wiki.osdev.org/Protected_mode
; + https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)

; The BIOS has its own IVT (Interupt Vector Table) and BDA (BIOS data area)
; The system therefore boots at address 0x7c00
org 0x7c00

section .boot
    ; First initialize segment registers
    jmp 0x00:0x7c05 ; Set cs = 0
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax

    jmp main

    ; Args : string
    strlen:
        push bp
        mov bp, sp
        push si

        xor cx, cx
        mov si, [bp+0x4]

        strlen_loop:
            mov dl, byte [ds:si] ; ds should be 0
            cmp dl, 0
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
    print_wait:
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

        ; Wait roughly 1 second
        mov ah, 0x86
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
        call print_wait
        mov ax, 0
        jmp test_a20_end

        ; Fail
        print_A20_disabled:
            push str_A20_disabled
            call print_wait
            mov ax, 1

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


    ; Load kernel from disk using CHS addressing
    ; Arg : drive number
    load_kernel:
        push bp
        mov bp, sp
        push es

        xor ax, ax
        mov es, ax
        mov ah, 2 ; CHS reading
        mov al, 1 ; We want to read 1 sector
        mov ch, 0 ; First cylinder
        mov cl, 2 ; Second sector (starts from 1)
        mov dx, [bp+0x4] ; dl = Drive number
        mov dh, 0 ; Head=0
        mov bx, 0x7e00 ; Store kernel at address es:bx -> 0x7e00 -> 0x7fff
        int 0x13

        pop es
        pop bp
        ret 2


    ; Main procedure
    main:
        push dx ; Drive number

        push str_welcome
        call print_wait

        push str_loading_kernel
        call print_wait
        call load_kernel

        call test_a20
        cmp ax, 0
        jne loop_main

        push str_setting_up_gdt
        call print_wait
        cli ; Disable interrupts
        call setup_gdt
        sti ; Enable again

        ; Set cr0 protected mode bit to 1
        push str_launching_protected_mode
        call print_wait
        cli
        mov eax, cr0
        or eax, 1
        mov cr0, eax

        ; Jumps to an adress using the newly defined code segment descriptor -> sets cs
        ; Which in turns enables protected-mode adressing using GDT and stuff
        jmp 0x08:main_0

        [BITS 32]
        main_0:
            ; Setup data segment and stack segment
            mov ax, 0x10
            mov ds, ax
            mov ss, ax

        jmp 0x7e00
        ; TODO : give control to kernel
        loop_main:
            jmp loop_main


    ; Data
    str_welcome:
        db "Welcome to the best bootloader ever, my friend!", 0

    str_loading_kernel:
        db "Loading kernel...", 0

    str_A20_enabled:
        db "A20 line is enabled", 0

    str_A20_disabled:
        db "A20 line is disabled :(", 0

    str_setting_up_gdt:
        db "Setting up GDT...", 0

    str_launching_protected_mode:
        db "Launching protected mode and booting kernel...", 0

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

    times 510-($-$$) db 0x90 ; Sector is 512 bytes long
    dw 0xaa55 ; End of sector needs magic bytes 55, aa

; Fill with As for now
section .kernel:
    times 512 db 0x90
