; ==============================================================================
; Project KannaOS - 24-Bit Operating System
; File: src/boot/boot.asm
; Stage-1 MBR Bootloader (Strictly 512 bytes)
; ==============================================================================

[BITS 16]
[ORG 0x7C00]

stage1_start:
    ; 1. Normalize segment registers and initialize stack below 0x7C00
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; 2. Save BIOS boot drive number
    mov [boot_drive], dl

    ; 3. Reset disk controller (INT 13h, AH=0x00)
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; 4. Read Stage 2 from disk to 0x0000:0x7E00 (immediately following MBR)
    ; We read 4 sectors (2,048 bytes)
    ; INT 13h, AH=0x02:
    ;   AL = number of sectors to read (4)
    ;   CH = cylinder (0)
    ;   CL = sector number (2, 1-indexed)
    ;   DH = head (0)
    ;   DL = drive number
    ;   ES:BX = destination pointer (0x0000:0x7E00)
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x7E00          ; Target buffer: 0x7E00

    mov ah, 0x02            ; BIOS Read Sectors
    mov al, 4               ; 4 sectors = 2,048 bytes
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Start at Sector 2 (Sector 1 was MBR)
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Boot drive
    int 0x13
    jc disk_error

    ; 5. Verify Stage 2 magic signature at 0x7E00
    ; Stage 2 begins with magic bytes: 0x4B 0x32 0x34 0x21 ("K24!")
    cmp dword [0x7E00], 0x2134324B   ; Little-endian "K24!"
    jne signature_error

    ; 6. Pass boot drive in DL and jump to Stage 2 entry point at 0x7E04
    mov dl, [boot_drive]
    jmp 0x0000:0x7E04

disk_error:
    mov si, msg_disk_err
    call print_bios
    cli
    hlt

signature_error:
    mov si, msg_sig_err
    call print_bios
    cli
    hlt

; Simple teletype print using BIOS INT 10h, AH=0x0E
print_bios:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print_bios
.done:
    ret

; ------------------------------------------------------------------------------
; Data
; ------------------------------------------------------------------------------
boot_drive      db 0
msg_disk_err    db "KannaOS Boot Error: Disk Read Failed", 13, 10, 0
msg_sig_err     db "KannaOS Boot Error: Invalid Stage2 Signature", 13, 10, 0

; ------------------------------------------------------------------------------
; Sector Padding & Boot Signature
; ------------------------------------------------------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
