; ==============================================================================
; Project KannaOS - 24-Bit Operating System
; File: src/iso/make_iso.asm
; Generates a 100% compliant El Torito Bootable ISO-9660 image with NASM
; ==============================================================================

[BITS 16]

; ------------------------------------------------------------------------------
; Sectors 0 to 15 (System Area / Unused): 16 * 2048 = 32,768 bytes
; ------------------------------------------------------------------------------
sector_0_15:
    times (16 * 2048) db 0

; ------------------------------------------------------------------------------
; Sector 16: Primary Volume Descriptor (PVD) (2,048 bytes)
; ------------------------------------------------------------------------------
sector_16_pvd:
    db 0x01                             ; Volume Descriptor Type: 1 = PVD
    db "CD001"                          ; Standard Identifier
    db 0x01                             ; Volume Descriptor Version: 1
    db 0x00                             ; Unused
    db "KANNAOS_HOST                    " ; System Identifier (32 chars)
    db "KANNAOS_BOOT                    " ; Volume Identifier (32 chars)
    times 8 db 0                        ; Unused (8 bytes)

    ; Volume Space Size: Total 2048-byte sectors in ISO (740 sectors = 0x2E4)
    ; Both-endian 32-bit: LSB followed by MSB
    dd 740                              ; LSB 32-bit
    dd 0xE4020000                       ; MSB 32-bit (big-endian 740)

    times 32 db 0                       ; Unused (32 bytes)
    dw 1, 0x0100                        ; Volume Set Size (1) both-endian
    dw 1, 0x0100                        ; Volume Sequence Number (1) both-endian
    dw 2048, 0x0008                     ; Logical Block Size (2048) both-endian
    dd 0, 0                             ; Path Table Size
    dd 0                                ; Location of Type L Path Table
    dd 0                                ; Location of Optional Type L Path Table
    dd 0                                ; Location of Type M Path Table
    dd 0                                ; Location of Optional Type M Path Table

    ; Root Directory Record (34 bytes dummy root)
    db 34                               ; Length of Directory Record
    db 0                                ; Extended Attribute Record Length
    dd 16, 0x10000000                   ; Location of Extent (both-endian)
    dd 2048, 0x00080000                 ; Data Length (both-endian)
    times 7 db 0                        ; Recording Date and Time
    db 0x02                             ; File Flags: Directory
    db 0, 0                             ; File Unit Size, Interleave Gap Size
    dw 1, 0x0100                        ; Volume Sequence Number (both-endian)
    db 1                                ; Length of File Identifier
    db 0                                ; File Identifier: 0 = Root

    db "KANNAOS                         " ; Volume Set Identifier (128 chars)
    times (128 - 32) db ' '
    db "PATNAM KANNABHIRAM              " ; Publisher Identifier (128 chars)
    times (128 - 32) db ' '
    db "KANNAOS OS SCRATCH              " ; Data Preparer Identifier (128 chars)
    times (128 - 32) db ' '
    db "KANNAOS BUILDER                 " ; Application Identifier (128 chars)
    times (128 - 32) db ' '

    times 37 db ' '                     ; Copyright File Identifier
    times 37 db ' '                     ; Abstract File Identifier
    times 37 db ' '                     ; Bibliographic File Identifier

    ; Volume Creation Date and Time (17 bytes: YYYYMMDDHHMMSScc + timezone)
    db "2026102815000000", 0

    ; Modification Date and Time
    db "2026102815000000", 0

    ; Expiration Date and Time
    times 17 db '0'

    ; Effective Date and Time
    db "2026102815000000", 0

    db 1                                ; File Structure Version
    db 0                                ; Reserved
    times 512 db 0                      ; Application Use
    times (2048 - ($ - sector_16_pvd)) db 0

; ------------------------------------------------------------------------------
; Sector 17: Boot Record Volume Descriptor (BRVD - El Torito) (2,048 bytes)
; ------------------------------------------------------------------------------
sector_17_brvd:
    db 0x00                             ; Boot Record Indicator (0)
    db "CD001"                          ; Standard Identifier
    db 0x01                             ; Version (1)
    db "EL TORITO SPECIFICATION", 0, 0, 0, 0, 0, 0, 0, 0, 0 ; 32 bytes
    times 32 db 0                       ; Unused
    dd 19                               ; Sector pointer to Boot Catalog (Sector 19)
    times (2048 - ($ - sector_17_brvd)) db 0

; ------------------------------------------------------------------------------
; Sector 18: Volume Descriptor Set Terminator (2,048 bytes)
; ------------------------------------------------------------------------------
sector_18_term:
    db 0xFF                             ; Terminator Type (255)
    db "CD001"                          ; Standard Identifier
    db 0x01                             ; Version (1)
    times (2048 - ($ - sector_18_term)) db 0

; ------------------------------------------------------------------------------
; Sector 19: Boot Catalog (2,048 bytes)
; ------------------------------------------------------------------------------
sector_19_catalog:
    ; 1. Validation Entry (32 bytes)
    db 0x01                             ; Header ID: 1
    db 0x00                             ; Platform ID: 0 (x86)
    dw 0x0000                           ; Reserved
    db "KannaOS Project         "       ; Developer ID (24 bytes)
    ; Checksum word: sum of all 16 words in 32-byte entry must equal 0
    dw (- (0x0001 + 0x0000 + 0x614B + 0x6E6E + 0x4F61 + 0x2053 + 0x7250 + 0x6A6F + 0x6365 + 0x2074 + 0x2020 + 0x2020 + 0x2020 + 0x2020 + 0xAA55)) & 0xFFFF
    dw 0xAA55                           ; Key signature bytes

    ; 2. Initial / Default Boot Entry (32 bytes)
    db 0x88                             ; Boot Indicator: 0x88 (Bootable)
    db 0x02                             ; Boot Media: 0x02 = 1.44M Floppy Emulation
    dw 0x0000                           ; Load Segment: 0x0000 (BIOS defaults to 0x07C0)
    db 0x00                             ; System Type
    db 0x00                             ; Unused
    dw 1                                ; Sector Count (1 virtual sector to load)
    dd 20                               ; Load RBA: Sector 20 (where boot image starts)
    times 20 db 0                       ; Reserved

    times (2048 - ($ - sector_19_catalog)) db 0

; ------------------------------------------------------------------------------
; Sector 20+: The 1.44 MiB Boot Image (720 sectors * 2048 = 1,474,560 bytes)
; ------------------------------------------------------------------------------
boot_image_start:
    ; Sector 1 of floppy (512 bytes): Stage 1 MBR Bootloader
    incbin "c:/KannaOS/build/boot.bin"

    ; Sector 2 to 5 of floppy (2,048 bytes): Stage 2 Host Loader
    incbin "c:/KannaOS/build/stage2.bin"

    ; Pad remaining 1.44M floppy image (1,474,560 bytes total)
    times (1474560 - ($ - boot_image_start)) db 0
