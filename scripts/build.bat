@echo off
setlocal enabledelayedexpansion

echo ==========================================================
echo  Building Project KannaOS (24-bit OS)
echo ==========================================================

cd /d "%~dp0\.."

set "NASM=nasm.exe"
where nasm.exe >nul 2>&1
if errorlevel 1 (
    if exist "%LOCALAPPDATA%\bin\NASM\nasm.exe" (
        set "NASM=%LOCALAPPDATA%\bin\NASM\nasm.exe"
    ) else (
        echo [ERROR] NASM assembler not found on PATH or in %%LOCALAPPDATA%%\bin\NASM.
        exit /b 1
    )
)

if not exist "build" mkdir "build"

echo [1/4] Assembling Stage 1 Bootloader...
"%NASM%" -f bin "src/boot/boot.asm" -o "build/boot.bin"
if errorlevel 1 goto error

echo [2/4] Assembling Stage 2 Host Loader...
"%NASM%" -f bin "src/boot/stage2.asm" -o "build/stage2.bin"
if errorlevel 1 goto error

echo [3/4] Generating Floppy Image (kannaos.img)...
"%NASM%" -f bin "src/iso/make_img.asm" -o "build/kannaos.img"
if errorlevel 1 goto error

echo [4/4] Generating El Torito Bootable ISO (kannaos.iso)...
"%NASM%" -f bin "src/iso/make_iso.asm" -o "build/kannaos.iso"
if errorlevel 1 goto error

echo ==========================================================
echo  BUILD SUCCESSFUL! Images ready in build/
echo ==========================================================
exit /b 0

:error
echo [ERROR] Build failed!
exit /b 1
