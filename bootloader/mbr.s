; MBR (Master Boot Record) : first 512 B sector that is booted by BIOS.
; This code simply :
; 0) Initializes segment register to 0
; 1) Loads the second stage of the bootloader

; The BIOS has its own IVT (Interupt Vector Table) and BDA (BIOS data area)
; The system therefore boots at address 0x7c00
org 0x7c00

section .mbr
    ; First initialize segment registers
    jmp 0x00:0x7c05 ; Set cs = 0
    ; Set ds, ss, es = 0
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax

    mov ah, 2 ; CHS reading
    mov al, 2 ; We want to read 2 sectors
    mov ch, 0 ; First cylinder
    mov cl, 2 ; Second sector (starts from 1)
    mov dh, 0 ; dh=Head=0, dl = Drive number
    mov bx, 0x7e00 ; Store 2nd stage bootloader at address es:bx -> 0x7e00 -> 0x81ff
    int 0x13

    jmp 0x7e00

    times 510-($-$$) db 0x90 ; Sector is 512 bytes long
    dw 0xaa55 ; End of sector needs magic bytes 55, aa

