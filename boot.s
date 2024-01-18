org 0x7c00  ; The BIOS has its own IVT and stuff it needs. So the bootcode is loaded at address 0x7c00 to make room for BIOS's own memory

section .boot
    ; Set extra segment register to zero
    xor ax, ax
    mov es, ax

    ; Set data segment register to 0xffff
    not ax
    mov ds, ax

    ; Output start status
    mov ax, str_welcome
    call print

    ; Wait roughly 1 second to see welcome screen
    mov ah, 0x86
    mov cx, 0x10
    xor dx, dx
    int 0x15

    ; Test if A20 gate is enabled
    mov si, 0x7c00 + 510
    mov ax, word [es:si] ; Should fetch magic number 0xaa55
    mov di, 0x7c00 + 0x100000 + 510 - 0xffff0
    mov bx, word [ds:di] ; Is it still the magic number ?

    cmp ax, bx
    je print_A20_disabled

    mov ax, str_A20_enabled
    call print
    jmp loop

    print_A20_disabled:
        mov ax, str_A20_disabled
        call print

    loop:
        jmp loop

    ; Args : string (ax)
    print:
        push bp
        push bx ; System V ABI : bx should be saved

        ; Set string as argument
        mov bp, ax

        ; Clear screen
        mov ah, 0x07    ; Scroll down window
        mov al, 0       ; Entire window
        mov bh, 0x0f    ; Attributes (colour)
        xor cx, cx      ; Row | Column of top left corner
        mov dx, 0x2050  ; Row | Column of bottom right corner (arbitrary here)
        int 0x10

        ; Display string
        ; First compute length of string
        mov ax, bp
        call strlen
        mov cx, ax

        mov ah, 0x13    ; Display string
        mov al, 1       ; Update cursor after writing
        mov bh, 0       ; Page number
        mov bl, 0x0f    ; Attributes (color)
        mov dx, 0       ; Row | Column
        int 0x10

        pop bx
        pop bp
        ret

    ; Args : string (ax)
    strlen:
        push bp
        push si

        xor cx, cx
        mov si, ax

        strlen_loop:
            mov dl, byte [es:si]
            cmp dl, 0
            jz strlen_end
            inc cx
            inc si
            jmp strlen_loop

        strlen_end:
            mov ax, cx
            pop si
            pop bp
            ret


    str_welcome:
        db "Welcome to the best bootloader ever, my friend!", 0

    str_A20_enabled:
        db "A20 line is enabled", 0

    str_A20_disabled:
        db "A20 line is disabled", 0


    times 510-($-$$) db 0x90 ; Sector is 512 bytes long
    dw 0xaa55 ; End of sector needs magic bytes 55, aa

