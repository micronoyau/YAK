org 0x7c00  ; The BIOS has its own IVT and stuff it needs. So the bootcode
            ; is loaded at address 0x7c00 to make room for BIOS's own memory

section .boot
    mov ax, 0
    mov es, ax      ; Initialize es to 0

    ; For BIOS interrupts see http://www.ctyme.com/intr/int-10.htm
    ; or https://en.wikipedia.org/wiki/INT_10H

    ; Clear screen
    mov ah, 0x07    ; Scroll down window
    mov al, 0       ; Entire window
    mov bh, 0x0f    ; Attributes (colour)
    xor cx, cx      ; Row | Column of top left corner
    mov dx, 0x2050  ; Row | Column of bottom right corner (arbitrary here)
    int 0x10

    ; Display string
    mov ah, 0x13    ; Display string
    mov al, 1       ; Update cursor after writing
    mov bh, 0       ; Page number
    mov bl, 0x0f    ; Attributes (color)
    mov cx, 13      ; Length of string
    mov dx, 0       ; Row | Column
    mov bp, string  ; String to display
    int 0x10

    ; Try out colors
    mov ah, 0x13    ; Display string
    mov al, 1       ; Update cursor after writing
    mov bh, 0       ; Page number
    xor bl, bl      ; Attributes (color)
    mov cx, 1       ; Length of string
    mov dx, 0x0100  ; Row | Column
    mov bp, whitespace ; String to display

    color:
        cmp bl, 0xf0
        jae loop
        int 0x10
        ; Increase background color
        shr bl, 4
        inc bl
        shl bl, 4
        inc dl ; Increase column
        jmp color

    loop:
        jmp loop

    whitespace:
        db ' ', 0

    string:
        db "Hello, world!", 0 ; Null-terminated string

    times 510-($-$$) db 0x90 ; Sector is 512 bytes long
    dw 0xaa55 ; End of sector needs magic bytes 55, aa

