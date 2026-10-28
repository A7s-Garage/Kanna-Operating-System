# ==============================================================================
# Project KannaOS - Build Script (PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
Set-Location $workspaceRoot

# Locate NASM
$nasmCmd = Get-Command nasm.exe -ErrorAction SilentlyContinue
if (-not $nasmCmd) {
    $fallbackNasm = "$env:LOCALAPPDATA\bin\NASM\nasm.exe"
    if (Test-Path $fallbackNasm) {
        $nasm = $fallbackNasm
    } else {
        Write-Error "NASM assembler not found. Please ensure nasm is in PATH or installed at $fallbackNasm"
        exit 1
    }
} else {
    $nasm = $nasmCmd.Source
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Building Project KannaOS (24-bit OS)" -ForegroundColor Green
Write-Host " Using NASM: $nasm" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

# Ensure build directory exists
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build" | Out-Null
}

# 1. Stage 1 MBR Bootloader (512 bytes)
Write-Host "[1/4] Assembling Stage 1 Bootloader (src/boot/boot.asm)..." -ForegroundColor Yellow
& $nasm -f bin "src/boot/boot.asm" -o "build/boot.bin"
$bootSize = (Get-Item "build/boot.bin").Length
if ($bootSize -ne 512) {
    Write-Error "boot.bin size is $bootSize bytes (must be exactly 512 bytes)!"
    exit 1
}
Write-Host "      -> build/boot.bin OK ($bootSize bytes)" -ForegroundColor Green

# 2. Stage 2 Host Loader (2048 bytes)
Write-Host "[2/4] Assembling Stage 2 Host Loader (src/boot/stage2.asm)..." -ForegroundColor Yellow
& $nasm -f bin "src/boot/stage2.asm" -o "build/stage2.bin"
$stage2Size = (Get-Item "build/stage2.bin").Length
if ($stage2Size -ne 2048) {
    Write-Error "stage2.bin size is $stage2Size bytes (must be exactly 2,048 bytes)!"
    exit 1
}
Write-Host "      -> build/stage2.bin OK ($stage2Size bytes)" -ForegroundColor Green

# 3. 1.44M Floppy Image (1,474,560 bytes)
Write-Host "[3/4] Generating Floppy Image (src/iso/make_img.asm)..." -ForegroundColor Yellow
& $nasm -f bin "src/iso/make_img.asm" -o "build/kannaos.img"
$imgSize = (Get-Item "build/kannaos.img").Length
if ($imgSize -ne 1474560) {
    Write-Error "kannaos.img size is $imgSize bytes (must be exactly 1,474,560 bytes)!"
    exit 1
}
Write-Host "      -> build/kannaos.img OK ($imgSize bytes)" -ForegroundColor Green

# 4. El Torito Bootable ISO-9660 (1,515,520 bytes)
Write-Host "[4/4] Generating El Torito Bootable ISO (src/iso/make_iso.asm)..." -ForegroundColor Yellow
& $nasm -f bin "src/iso/make_iso.asm" -o "build/kannaos.iso"
$isoSize = (Get-Item "build/kannaos.iso").Length
if ($isoSize -ne 1515520) {
    Write-Error "kannaos.iso size is $isoSize bytes (must be exactly 1,515,520 bytes)!"
    exit 1
}
Write-Host "      -> build/kannaos.iso OK ($isoSize bytes)" -ForegroundColor Green

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " BUILD SUCCESSFUL! All boot targets ready to run." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
