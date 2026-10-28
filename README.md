# Project KannaOS (24-Bit Operating System)

**KannaOS** is an operating system built from scratch around a custom 24-bit computer architecture named **K24**.

---

## 🎯 Architecture Summary

- **Word Size:** 24 bits (3 octets, values `$000000` to `$FFFFFF` / 0 to 16,777,215).
- **Address Space:** 16 MiB flat byte-addressed (`$000000` to `$FFFFFF`).
- **Endianness:** Strictly Little-Endian.
- **Registers:** 10 programmer-visible 24-bit registers:
  - `R0` (Accumulator / Syscall ID), `R1` (Counter / Arg 1), `R2` (Data Pointer / Arg 2), `R3` (Index / Arg 3)
  - `R4`, `R5` (General Purpose, callee-saved)
  - `R6` (Frame Pointer `FP`), `R7` (Link Register `LR`)
  - `PC` (Program Counter, resets to `$001000`)
  - `SP` (Stack Pointer, resets to `$100000`, full-descending)
  - `FLAGS` (`Z`, `C`, `N`, `V`, `I`)
- **Execution Model:**
  1. **x86 Micro-Host (Hardware Layer):** Legacy BIOS bare-metal runtime initializing VGA text mode, PS/2 keyboard controller, and hosting the K24 virtual machine.
  2. **K24 Virtual Machine & Kernel:** 24-bit native operating system executing inside the K24 execution engine with `TRAP 0x20` host services.

---

## 🚀 Current Status: Milestone 1 Complete & Live

| Component | Status | Details |
| :--- | :--- | :--- |
| **Milestone 0: Canonical Spec** | ✅ Complete | [k24_architecture_spec.md](docs/k24_architecture_spec.md) |
| **Stage 1 Bootloader** | ✅ Complete | [boot.asm](src/boot/boot.asm) (512 bytes, MBR sector 1, reads Stage 2) |
| **Stage 2 Host Loader** | ✅ Complete | [stage2.asm](src/boot/stage2.asm) (VGA 80x25 text mode, interactive PS/2 keyboard loop) |
| **1.44 MiB Floppy Disk** | ✅ Complete | [make_img.asm](src/iso/make_img.asm) (`build/kannaos.img`, 1,474,560 bytes) |
| **El Torito Bootable ISO** | ✅ Complete | [make_iso.asm](src/iso/make_iso.asm) (`build/kannaos.iso`, 1,515,520 bytes) |
| **VirtualBox VM Integration** | ✅ Tested & Running | Boots cleanly, displays blue banner, processes interactive keystrokes |

---

## 🛠️ How to Build and Run

### 1. Requirements
- **NASM** (Netwide Assembler, version 2.15+ or 3.0+)
- **Oracle VirtualBox** (version 7.0+)

### 2. Build All Targets
From PowerShell or CMD in the project root:
```powershell
# PowerShell
.\scripts\build.ps1

# Or Command Prompt / Batch
.\scripts\build.bat
```
This generates:
- `build/boot.bin` (512 bytes)
- `build/stage2.bin` (2,048 bytes)
- `build/kannaos.img` (1,474,560 bytes)
- `build/kannaos.iso` (1,515,520 bytes)

### 3. Run in VirtualBox
```powershell
# Launch the VM in VirtualBox GUI:
.\scripts\run.ps1

# Or double-click / run:
.\scripts\run.bat

# Or run headless (for automated tests):
.\scripts\run.ps1 -Headless
```

---

## 🗺️ Roadmap Ahead

- **Milestone 2:** 24-Bit Virtual CPU Instruction Interpreter & Core Fetch-Decode-Execute Loop.
- **Milestone 3:** SIB (System Information Block), IVT (Interrupt Vector Table), and `TRAP 0x20` Host Syscall Dispatcher.
- **Milestone 4:** K24 Native Kernel, Memory Allocator, and Interactive Command Shell.
