CGA_BUF_SEG: equ 0xb800
CGA_BUF_SIZE: equ 0x4000
NUM_OF_PIXELS: equ 320 * 200

    org 0x0100
    mov ax, 0x0004
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0111
    int 0x10
    mov ax, CGA_BUF_SEG
    push ax
    pop es
    cld
    mov al, 0x1b
    xor di, di
draw_row_even:
    mov cx, 2000
    rep stosb
    ror al, 2
    cmp di, 8000
    jb draw_row_even
    mov al, 0xe4
    mov di, 0x2000
draw_row_odd:
    mov cx, 2000
    rep stosb
    rol al, 2
    cmp di, CGA_BUF_SIZE
    jb draw_row_odd
    xor ax, ax
    int 0x16
    mov ax, 0x0002
    int 0x10
    int 0x20