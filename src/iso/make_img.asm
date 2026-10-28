; ==============================================================================
; Project KannaOS - 24-Bit Operating System
; File: src/iso/make_img.asm
; Generates standard 1.44 MiB floppy disk image (kannaos.img)
; ==============================================================================

[BITS 16]

img_start:
    ; Sector 1: Stage 1 MBR Bootloader (512 bytes)
    incbin "c:/KannaOS/build/boot.bin"

    ; Sectors 2 to 5: Stage 2 Host Loader (2,048 bytes)
    incbin "c:/KannaOS/build/stage2.bin"

    ; Pad to 1,474,560 bytes (2,880 sectors of 512 bytes)
    times (1474560 - ($ - img_start)) db 0
