; ==============================================================================
; Project KannaOS - 24-Bit Operating System
; File: src/boot/stage2.asm
; Stage-2 Host Loader & Milestone 1 Startup Banner
; ==============================================================================

[BITS 16]
[ORG 0x7E00]

; ------------------------------------------------------------------------------
; Stage 2 Header with Magic Signature
; ------------------------------------------------------------------------------
stage2_header:
    db 'K', '2', '4', '!'   ; 4-byte signature: 0x4B323421

stage2_entry:
    ; DL contains boot drive number from Stage 1
    mov [boot_drive], dl

    ; 1. Set VGA 80x25 16-color text mode (BIOS INT 10h, AH=0x00, AL=0x03)
    mov ax, 0x0003
    int 0x10

    ; 2. Hide hardware cursor or set scan lines (INT 10h, AH=0x01, CH=0x20)
    mov ah, 0x01
    mov ch, 0x20
    int 0x10

    ; 3. Clear screen with custom background attribute
    ; Attribute: 0x1F = Bright White on Blue background
    mov ax, 0x0600          ; AH=06 (scroll/clear), AL=00 (entire window)
    mov bh, 0x1F            ; Blue background (1), White text (F)
    xor cx, cx              ; Row 0, Col 0
    mov dx, 0x184F          ; Row 24 (0x18), Col 79 (0x4F)
    int 0x10

    ; 4. Print Startup Banner lines
    mov si, banner_line1
    mov dh, 1               ; Row 1
    mov dl, 0               ; Col 0
    call print_string_at

    mov si, banner_title
    mov dh, 3               ; Row 3
    mov dl, 14              ; Centered Col 14
    call print_string_at

    mov si, banner_sub
    mov dh, 4               ; Row 4
    mov dl, 15              ; Centered Col 15
    call print_string_at

    mov si, banner_line2
    mov dh, 6               ; Row 6
    mov dl, 0
    call print_string_at

    mov si, info_host
    mov dh, 8               ; Row 8
    mov dl, 4
    call print_string_at

    mov si, info_cpu
    mov dh, 10              ; Row 10
    mov dl, 4
    call print_string_at

    mov si, info_mem
    mov dh, 12              ; Row 12
    mov dl, 4
    call print_string_at

    mov si, info_stack
    mov dh, 14              ; Row 14
    mov dl, 4
    call print_string_at

    mov si, info_status
    mov dh, 16              ; Row 16
    mov dl, 4
    call print_string_at

    mov si, banner_line2
    mov dh, 18              ; Row 18
    mov dl, 0
    call print_string_at

    mov si, prompt_key
    mov dh, 20              ; Row 20
    mov dl, 4
    call print_string_at

    mov si, footer_text
    mov dh, 23              ; Row 23
    mov dl, 4
    call print_string_at

; ------------------------------------------------------------------------------
; Main Interactive Loop: Respond to keyboard strokes
; ------------------------------------------------------------------------------
main_loop:
    ; Wait for key press (INT 16h, AH=0x00)
    mov ah, 0x00
    int 0x16

    ; AL contains ASCII character
    ; Print notification that key was detected
    push ax
    mov si, key_detected_msg
    mov dh, 21
    mov dl, 4
    call print_string_at

    ; Print the pressed key in brackets
    pop ax
    mov [pressed_char], al
    mov si, pressed_char_str
    mov dh, 21
    mov dl, 39
    call print_string_at

    jmp main_loop

; ------------------------------------------------------------------------------
; Helper: print_string_at
; Inputs: SI = pointer to null-terminated string, DH = Row, DL = Col
; ------------------------------------------------------------------------------
print_string_at:
    pusha
.next_char:
    lodsb
    test al, al
    jz .done

    ; Set cursor position (INT 10h, AH=0x02, BH=0x00)
    mov ah, 0x02
    mov bh, 0x00
    int 0x10

    ; Write character with attribute (INT 10h, AH=0x09)
    mov ah, 0x09
    mov bh, 0x00            ; Page 0
    mov bl, 0x1F            ; Bright White on Blue
    mov cx, 1               ; 1 character
    int 0x10

    ; Advance column
    inc dl
    cmp dl, 80
    jb .next_char
    xor dl, dl
    inc dh
    jmp .next_char

.done:
    popa
    ret

; ------------------------------------------------------------------------------
; Data Strings & Variables
; ------------------------------------------------------------------------------
boot_drive          db 0

banner_line1        db "================================================================================", 0
banner_title        db "***  PROJECT KANNAOS - 24-BIT OPERATING SYSTEM  ***", 0
banner_sub          db "Bare-Metal Micro-Host & K24 Virtual Execution Environment", 0
banner_line2        db "--------------------------------------------------------------------------------", 0

info_host           db "[HOST]   x86 Legacy BIOS Bare-Metal Host | Oracle VirtualBox Verified", 0
info_cpu            db "[CPU]    Target: K24 Virtual CPU (24-bit Registers R0-R7, PC, SP, FLAGS)", 0
info_mem            db "[MEM]    16 MiB Flat Byte-Addressed Logical Space ($000000 - $FFFFFF)", 0
info_stack          db "[STACK]  Full-Descending ($100000 Top -> $080000 Limit, 512 KiB)", 0
info_status         db "[STATUS] Milestone 1: BIOS Bootloader & ISO Pipeline Operational", 0

prompt_key          db ">> System Ready. Press any key to test keyboard input...", 0
key_detected_msg    db ">> Keyboard Event Received: Key = [ ]", 0
pressed_char_str:
pressed_char        db " ", 0
footer_text         db "KannaOS (c) 2026 Patnam Kannabhiram | Open-Source 24-Bit OS Project", 0

; ------------------------------------------------------------------------------
; Pad Stage 2 to exactly 4 sectors (2,048 bytes)
; ------------------------------------------------------------------------------
times 2048 - ($ - $$) db 0
