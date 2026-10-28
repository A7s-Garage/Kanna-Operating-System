# K24 Architecture Specification
**Version 1.0 — Milestone 0 Canonical Specification**
**Project:** KannaOS (24-bit Operating System)

---

## 1. Introduction and Architectural Principles

KannaOS is designed from scratch around a custom 24-bit computer architecture named **K24**. 

Because standard commodity x86 processors lack native 24-bit instruction decoders and general-purpose registers, KannaOS adopts a two-layer execution model:
1. **The x86 Micro-Host (Hardware Layer):** A small x86 runtime booted directly by legacy BIOS on bare metal / VirtualBox. It initializes physical hardware (VGA $80 \times 25$ text mode, PS/2 keyboard controller, timer, disk) and provides the virtual CPU execution engine for K24.
2. **KannaOS (Native 24-bit Operating System):** The entire operating system—including the kernel, stack, interrupt handlers, memory allocator, and interactive shell—is written in K24 machine instructions and executes strictly within the K24 virtual CPU.

---

## 2. Fundamental Units and Numerical Representation

| Unit | Size | Value Range |
| :--- | :--- | :--- |
| **Byte** | 8 bits | `$00` to `$FF` (0 to 255) |
| **Word** | 24 bits (3 octets) | `$000000` to `$FFFFFF` (0 to 16,777,215) |
| **Address** | 24 bits | `$000000` to `$FFFFFF` (16 MiB flat byte-addressed) |

### 2.1 Endianness
K24 is strictly **Little-Endian**:
- In any 24-bit word stored in memory at byte address $A$:
  - Memory at address $A + 0$: Bits $[7:0]$ (Least Significant Byte)
  - Memory at address $A + 1$: Bits $[15:8]$ (Middle Byte)
  - Memory at address $A + 2$: Bits $[23:16]$ (Most Significant Byte)

### 2.2 Integer Representation
- **Unsigned 24-bit integers:** $0 \le X \le 16,777,215$ ($2^{24} - 1$).
- **Signed 24-bit integers:** Two's complement representation:
  - Minimum negative value: $-8,388,608$ (`$800000`, $-2^{23}$).
  - Maximum positive value: $+8,388,607$ (`$7FFFFF`, $+2^{23} - 1$).
  - Sign bit: Bit 23 (`1` = negative, `0` = non-negative).

---

## 3. Register Architecture

K24 provides ten programmer-visible 24-bit registers:

```
23                                                           0
┌─────────────────────────────────────────────────────────────┐
│                   R0 (Primary Accumulator / Return)         │  0x0
├─────────────────────────────────────────────────────────────┤
│                   R1 (Counter / Secondary Return)           │  0x1
├─────────────────────────────────────────────────────────────┤
│                   R2 (Base Pointer / Data Register)         │  0x2
├─────────────────────────────────────────────────────────────┤
│                   R3 (Index Register / Scratch)             │  0x3
├─────────────────────────────────────────────────────────────┤
│                   R4 (General Purpose)                      │  0x4
├─────────────────────────────────────────────────────────────┤
│                   R5 (General Purpose)                      │  0x5
├─────────────────────────────────────────────────────────────┤
│                   R6 (Frame Pointer - FP convention)        │  0x6
├─────────────────────────────────────────────────────────────┤
│                   R7 (Link Register - LR convention)        │  0x7
├─────────────────────────────────────────────────────────────┤
│                   PC (Program Counter)                      │  0x8
├─────────────────────────────────────────────────────────────┤
│                   SP (Stack Pointer)                        │  0x9
├─────────────────────────────────────────────────────────────┤
│                   FLAGS (Status Register)                   │  0xA
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Register Encodings (4-bit field in instructions)

| Register | Index (Binary) | Index (Hex) | Architectural Role / Standard ABI Convention |
| :--- | :--- | :--- | :--- |
| `R0` | `0000b` | `0x0` | Primary Accumulator, function return value, host syscall ID |
| `R1` | `0001b` | `0x1` | Secondary Accumulator, div modulo output, syscall arg 1 |
| `R2` | `0010b` | `0x2` | Data Pointer, base register, syscall arg 2 |
| `R3` | `0011b` | `0x3` | Index Register, loop counter, syscall arg 3 |
| `R4` | `0100b` | `0x4` | General Purpose (Callee-saved) |
| `R5` | `0101b` | `0x5` | General Purpose (Callee-saved) |
| `R6` | `0110b` | `0x6` | Frame Pointer (`FP`) / Callee-saved |
| `R7` | `0111b` | `0x7` | Subroutine Link Register (`LR`) / Callee-saved |
| `PC` | `1000b` | `0x8` | Program Counter (holds byte address of next instruction) |
| `SP` | `1001b` | `0x9` | Stack Pointer (points to top of stack) |
| `FLAGS` | `1010b` | `0xA` | Processor status flags |

### 3.2 The FLAGS Register (24-bit)

```
23                                              5   4   3   2   1   0
┌─────────────────────────────────────────────┬───┬───┬───┬───┬───┬───┐
│              Reserved (Read as 0)           │ R │ I │ V │ N │ C │ Z │
└─────────────────────────────────────────────┴───┴───┴───┴───┴───┴───┘
```

- **Bit 0 (`Z` - Zero Flag):** Set to `1` if the result of an arithmetic, logical, or test operation is zero; cleared to `0` otherwise.
- **Bit 1 (`C` - Carry / Borrow Flag):** Set to `1` if an unsigned addition produced a carry out of bit 23, or if an unsigned subtraction produced a borrow. Cleared to `0` otherwise.
- **Bit 2 (`N` - Negative / Sign Flag):** Set to `1` if bit 23 of the result is `1` (negative in two's complement); cleared to `0` otherwise.
- **Bit 3 (`V` - Overflow Flag):** Set to `1` if a signed arithmetic operation resulted in two's complement overflow; cleared to `0` otherwise.
- **Bit 4 (`I` - Interrupt Enable Flag):** When `1`, maskable hardware events (timer, keyboard) can trigger virtual interrupts. When `0`, interrupts are masked.
- **Bits 5–23:** Reserved for future architecture revisions; always read as `0`.

---

## 4. Memory Model and Logical Address Map

The K24 memory architecture is a flat, byte-addressed address space of exactly **$2^{24} = 16,777,216$ bytes (16 MiB)** spanning addresses `$000000` to `$FFFFFF`.

### 4.1 Memory Map Partitions (Contiguous, Non-Overlapping)

```
0x000000 ┌──────────────────────────────────────────────────────────┐
         │ Interrupt Vector Table (IVT) - 256 vectors x 4 bytes     │ 1 KiB
0x0003FF ├──────────────────────────────────────────────────────────┤
0x000400 │ System Information Block (SIB) & Host Tables             │ 3 KiB
0x000FFF ├──────────────────────────────────────────────────────────┤
0x001000 │ KannaOS Kernel Code & Static Data (Entry Point: 0x001000)│ ~508 KiB
0x07FFFF ├──────────────────────────────────────────────────────────┤
0x080000 │ Kernel Stack Segment (Grows downward from 0x100000)      │ 512 KiB
0x0FFFFF ├──────────────────────────────────────────────────────────┤
0x100000 │ Dynamic Memory (Heap, Disk Buffers, User Space)          │ 15 MiB
0xFFFFFF └──────────────────────────────────────────────────────────┘
```

| Region | Start Address | End Address | Size | Access Rules / Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **IVT** | `$000000` | `$0003FF` | 1,024 B (1 KiB) | 256 4-byte entries. Read/Write by kernel to register interrupt handlers. |
| **SIB** | `$000400` | `$000FFF` | 3,072 B (3 KiB) | Populated by x86 micro-host at startup with hardware capabilities. Read-only to OS. |
| **Kernel Space** | `$001000` | `$07FFFF` | 520,192 B (~508 KiB) | KannaOS kernel binary text and initialized data. |
| **Kernel Stack** | `$080000` | `$0FFFFF` | 524,288 B (512 KiB) | Stack space for kernel execution. Full-descending. Top limit `$100000`, bottom limit `$080000`. |
| **Dynamic Space** | `$100000` | `$FFFFFF` | 15,728,640 B (15 MiB) | Managed by KannaOS dynamic memory manager (heap allocations, buffers, user tasks). |

---

## 5. Stack Architecture and Semantics

The K24 stack follows a **Full-Descending** model (identical to ARM and x86 conventions):
- The Stack Pointer `SP` points directly to the **last valid data item pushed** onto the stack.
- The stack grows towards lower memory addresses.

### 5.1 Push Word (`PUSH Rs`) — 24-bit Word
1. Decrement stack pointer by 3 bytes: `SP = SP - 3`
2. Check stack bounds: If `SP < $080000`, trigger Exception Vector `0x07` (Stack Fault).
3. Store `Rs` little-endian:
   - `MEM[SP + 0] = Rs[7:0]`
   - `MEM[SP + 1] = Rs[15:8]`
   - `MEM[SP + 2] = Rs[23:16]`

### 5.2 Pop Word (`POP Rd`) — 24-bit Word
1. Check stack bounds: If `SP > $100000 - 3`, trigger Exception Vector `0x07` (Stack Underflow Fault).
2. Load 24-bit word little-endian:
   - `Rd = MEM[SP + 0] | (MEM[SP + 1] << 8) | (MEM[SP + 2] << 16)`
3. Increment stack pointer by 3 bytes: `SP = SP + 3`

### 5.3 Byte Push/Pop (`PUSH8 Rs`, `POP8 Rd`)
- `PUSH8 Rs`: `SP = SP - 1`; `MEM[SP] = Rs[7:0]`
- `POP8 Rd`: `Rd = MEM[SP]`; `SP = SP + 1` (Bits $[23:8]$ of `Rd` are cleared to zero).

---

## 6. Processor Reset State

When the K24 execution engine is initialized or reset:
- `PC` = `$001000` (First instruction of KannaOS kernel)
- `SP` = `$100000` (Empty stack top; first `PUSH` decrements to `$0FFFFD`)
- `FLAGS` = `$000000` (All flags zero: `Z=0, C=0, N=0, V=0, I=0` - interrupts disabled)
- `R0` through `R7` = `$000000`

---

## 7. Instruction Formats and Encoding

Every basic instruction is **24 bits (1 word = 3 bytes)**.
When an instruction requires a 24-bit immediate operand or a 24-bit absolute memory address, it uses the **Extended 48-bit (2 words = 6 bytes)** format.

### 7.1 Instruction Word Layout (Little-Endian)
In memory, the first word of every instruction is laid out as:
- Byte 0: Bits $[7:0]$
- Byte 1: Bits $[15:8]$
- Byte 2: Bits $[23:16]$

### 7.2 The Four Primary Instruction Formats

#### Format 1: Register-Register (RR) — 24 bits (1 Word)
Used for ALU operations, moves, and single-register operations.
```
23            16 15      12 11       8 7             0
┌───────────────┬──────────┬──────────┬───────────────┐
│  Opcode (8)   │  Rd (4)  │  Rs (4)  │ Sub/Func (8)  │
└───────────────┴──────────┴──────────┴───────────────┘
```

#### Format 2: Register-Immediate8 (RI8) — 24 bits (1 Word)
Used for 8-bit arithmetic, small constants, shifts, and 8-bit I/O traps.
```
23            16 15      12 11       8 7             0
┌───────────────┬──────────┬──────────┬───────────────┐
│  Opcode (8)   │  Rd (4)  │  Rs (4)  │   Imm8 (8)    │
└───────────────┴──────────┴──────────┴───────────────┘
```

#### Format 3: Branch Relative (BR) — 24 bits (1 Word)
Used for conditional and unconditional relative jumps.
```
23            16 15      12 11                       0
┌───────────────┬──────────┬──────────────────────────┐
│  Opcode (8)   │ Cond (4) │ Signed Word Offset (12)  │
└───────────────┴──────────┴──────────────────────────┘
```
- Offset is signed 12-bit two's complement: $-2048$ to $+2047$ words.
- Byte branch target: $\text{Target} = \text{PC} + 3 + (\text{Offset12} \times 3)$.

#### Format 4: Extended Immediate24 / Direct Memory (EXT24) — 48 bits (2 Words)
Used for 24-bit constants, absolute jumps, absolute calls, and direct memory load/store.
```
Word 1:
23            16 15      12 11       8 7             0
┌───────────────┬──────────┬──────────┬───────────────┐
│  Opcode (8)   │  Rd (4)  │  Rb (4)  │ Mode/Sub (8)  │
└───────────────┴──────────┴──────────┴───────────────┘
Word 2:
23                                                   0
┌─────────────────────────────────────────────────────┐
│    Imm24 / Absolute 24-bit Memory Address (24)      │
└─────────────────────────────────────────────────────┘
```

---

## 8. Condition Codes (Cond Field)

Branches and conditional instructions encode a 4-bit condition test in bits $[15:12]$:

| Code | Mnemonic | Condition Tested | Flag Expression |
| :--- | :--- | :--- | :--- |
| `0x0` | `AL` | Always (Unconditional) | `1` |
| `0x1` | `EQ` | Equal / Zero | `Z == 1` |
| `0x2` | `NE` | Not Equal / Non-Zero | `Z == 0` |
| `0x3` | `CS` / `HS` | Carry Set / Unsigned Higher or Same | `C == 1` |
| `0x4` | `CC` / `LO` | Carry Clear / Unsigned Lower | `C == 0` |
| `0x5` | `MI` | Minus / Negative | `N == 1` |
| `0x6` | `PL` | Plus / Positive or Zero | `N == 0` |
| `0x7` | `VS` | Overflow Set | `V == 1` |
| `0x8` | `VC` | Overflow Clear | `V == 0` |
| `0x9` | `HI` | Unsigned Higher | `(C == 1) and (Z == 0)` |
| `0xA` | `LS` | Unsigned Lower or Same | `(C == 0) or (Z == 1)` |
| `0xB` | `GE` | Signed Greater Than or Equal | `N == V` |
| `0xC` | `LT` | Signed Less Than | `N != V` |
| `0xD` | `GT` | Signed Greater Than | `(Z == 0) and (N == V)` |
| `0xE` | `LE` | Signed Less Than or Equal | `(Z == 1) or (N != V)` |
| `0xF` | `NV` | Never (Reserved / NOP) | `0` |

---

## 9. Complete Instruction Set Architecture

### 9.1 Control Flow & System Operations

| Opcode | Mnemonic & Operands | Format | Words | Action & Flags Affected |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `NOP` | RR | 1 | No operation. |
| `0x01` | `HALT` | RR | 1 | Halts CPU until next interrupt (or ends execution). |
| `0x02` | `TRAP imm8` | RI8 | 1 | Triggers software exception vector `imm8`. Pushes `FLAGS`, pushes `PC+3`, clears `I`, jumps to `IVT[imm8]`. |
| `0x03` | `IRET` | RR | 1 | Return from interrupt. Pops `PC`, pops `FLAGS`. |
| `0x04` | `RET` | RR | 1 | Return from subroutine. Pops `PC` from stack. |
| `0x05` | `CALL addr24` | EXT24 | 2 | Call subroutine: pushes `PC+6` to stack, sets `PC = addr24`. |
| `0x06` | `CALLR Rs` | RR | 1 | Indirect call: pushes `PC+3` to stack, sets `PC = Rs`. |
| `0x07` | `JMP addr24` | EXT24 | 2 | Unconditional jump: sets `PC = addr24`. |
| `0x08` | `JMPR Rs` | RR | 1 | Indirect jump: sets `PC = Rs`. |
| `0x09` | `Bcc rel12` | BR | 1 | Conditional relative branch: if `cc` is true, `PC = PC + 3 + (rel12 * 3)`. |
| `0x0A` | `STI` | RR | 1 | Set interrupt flag: `FLAGS.I = 1`. |
| `0x0B` | `CLI` | RR | 1 | Clear interrupt flag: `FLAGS.I = 0`. |

### 9.2 Data Movement

| Opcode | Mnemonic & Operands | Format | Words | Action & Flags Affected |
| :--- | :--- | :--- | :--- | :--- |
| `0x10` | `MOV Rd, Rs` | RR | 1 | `Rd = Rs`. Flags unaffected. |
| `0x11` | `LDI8 Rd, imm8` | RI8 | 1 | `Rd = ZeroExtend(imm8)`. Flags: `Z, N` updated. |
| `0x12` | `LDI24 Rd, imm24` | EXT24 | 2 | `Rd = imm24`. Flags: `Z, N` updated. |
| `0x13` | `LD24 Rd, [Rs]` | RR | 1 | `Rd = MEM24[Rs]`. Flags unaffected. |
| `0x14` | `ST24 [Rd], Rs` | RR | 1 | `MEM24[Rd] = Rs`. Flags unaffected. |
| `0x15` | `LD8 Rd, [Rs]` | RR | 1 | `Rd = ZeroExtend(MEM8[Rs])`. Flags unaffected. |
| `0x16` | `ST8 [Rd], Rs` | RR | 1 | `MEM8[Rd] = Rs[7:0]`. Flags unaffected. |
| `0x17` | `LD24O Rd, [Rs + imm8]` | RI8 | 1 | `Rd = MEM24[Rs + imm8]`. Offset is unsigned 8-bit. |
| `0x18` | `ST24O [Rd + imm8], Rs` | RI8 | 1 | `MEM24[Rd + imm8] = Rs`. Offset is unsigned 8-bit. |
| `0x19` | `PUSH Rs` | RR | 1 | Push 24-bit `Rs` to stack: `SP=SP-3`, `MEM24[SP]=Rs`. |
| `0x1A` | `POP Rd` | RR | 1 | Pop 24-bit word into `Rd`: `Rd=MEM24[SP]`, `SP=SP+3`. |

### 9.3 Arithmetic and Logic Operations

All arithmetic and logic operations operate on 24-bit words.

| Opcode | Mnemonic & Operands | Format | Words | Semantics & Flag Effects |
| :--- | :--- | :--- | :--- | :--- |
| `0x20` | `ADD Rd, Rs` | RR | 1 | $Rd = Rd + Rs$. Flags: `Z, N, C, V`. |
| `0x21` | `ADDC Rd, Rs` | RR | 1 | $Rd = Rd + Rs + C$. Flags: `Z, N, C, V`. |
| `0x22` | `SUB Rd, Rs` | RR | 1 | $Rd = Rd - Rs$. Flags: `Z, N, C, V`. |
| `0x23` | `SUBC Rd, Rs` | RR | 1 | $Rd = Rd - Rs - C$. Flags: `Z, N, C, V`. |
| `0x24` | `CMP Rd, Rs` | RR | 1 | Computes $Rd - Rs$. Updates `Z, N, C, V`; result discarded. |
| `0x25` | `AND Rd, Rs` | RR | 1 | $Rd = Rd \ \& \ Rs$. Flags: `Z, N` (`C=0, V=0`). |
| `0x26` | `OR Rd, Rs` | RR | 1 | $Rd = Rd \ \| \ Rs$. Flags: `Z, N` (`C=0, V=0`). |
| `0x27` | `XOR Rd, Rs` | RR | 1 | $Rd = Rd \ \oplus \ Rs$. Flags: `Z, N` (`C=0, V=0`). |
| `0x28` | `NOT Rd` | RR | 1 | $Rd = \sim Rd$ (one's complement). Flags: `Z, N`. |
| `0x29` | `NEG Rd` | RR | 1 | $Rd = -Rd$ (two's complement). Flags: `Z, N, C, V`. |
| `0x2A` | `SHL Rd, imm8` | RI8 | 1 | Logical shift left: $Rd = (Rd \ll imm8) \& \$FFFFFF$. Flags: `Z, N, C`. |
| `0x2B` | `SHR Rd, imm8` | RI8 | 1 | Logical shift right: $Rd = Rd \gg imm8$. Flags: `Z, N, C`. |
| `0x2C` | `SAR Rd, imm8` | RI8 | 1 | Arithmetic shift right (sign-extended): Flags: `Z, N, C`. |
| `0x2D` | `MUL Rd, Rs` | RR | 1 | $Rd = (Rd \times Rs) \& \$FFFFFF$. `R1` holds upper 24 bits. Flags: `Z, N`. |
| `0x2E` | `DIV Rd, Rs` | RR | 1 | If $Rs == 0$, trigger Vector 0. Else $Rd = Rd / Rs$, $R1 = Rd \pmod{Rs}$. Flags: `Z, N`. |

---

## 10. Arithmetic Flag Generation Rules

For any 24-bit binary operation producing result $R = Rd \text{ op } Rs$:

- **Zero Flag (`Z`):**
  $$Z = (R \& \$FFFFFF == 0) \ ? \ 1 : 0$$
- **Negative Flag (`N`):**
  $$N = ((R \gg 23) \& 1)$$
- **Carry Flag (`C`):**
  - For Addition (`ADD`): $C = 1$ if $(Rd + Rs) > \$FFFFFF$, else $0$.
  - For Subtraction (`SUB`, `CMP`): $C = 1$ if $Rd < Rs$ (borrow occurred), else $0$.
- **Overflow Flag (`V`):**
  - For Addition (`ADD`): $V = 1$ if both operands have the same sign bit (bit 23) and the result has an opposite sign bit:
    $$V = (((Rd \oplus R) \& (Rs \oplus R)) \gg 23) \& 1$$
  - For Subtraction (`SUB`, `CMP`): $V = 1$ if operands have different sign bits and result sign matches subtrahend:
    $$V = (((Rd \oplus Rs) \& (Rd \oplus R)) \gg 23) \& 1$$

---

## 11. Interrupt and Exception Handling

### 11.1 The Interrupt Vector Table (IVT)
The IVT occupies `$000000` to `$0003FF` (256 vectors, 4 bytes per vector):
- **Bytes 0–2:** 24-bit handler target address (Little-Endian).
- **Byte 3:** Attributes / Flags (Bit 7: Present flag, `$80` = active).

```
Vector Entry Format:
Byte 0: Handler Address [7:0]
Byte 1: Handler Address [15:8]
Byte 2: Handler Address [23:16]
Byte 3: Control Flags (0x80 = Present)
```

### 11.2 Standard Vector Allocations

| Vector | Name | Trigger / Description |
| :--- | :--- | :--- |
| `0x00` | Divide-by-Zero | Triggered when `DIV` executes with divisor equal to 0. |
| `0x01` | Single Step | Debug trap after every instruction when debug mode is enabled. |
| `0x02` | Non-Maskable Interrupt | Hardware emergency / host fault. |
| `0x03` | Breakpoint | Software breakpoint (`HALT` or trap). |
| `0x04` | Arithmetic Overflow | Triggered by `INTO` (Interrupt on Overflow). |
| `0x05` | Bounds Violation | Pointer or index out of valid range. |
| `0x06` | Invalid Opcode | Attempt to decode an unknown or reserved instruction opcode. |
| `0x07` | Stack Fault | Stack pointer exceeded bounds (`SP < $080000` or `SP > $100000`). |
| `0x08` | System Timer IRQ | Periodic tick from host timer (e.g. 100 Hz). |
| `0x09` | Keyboard IRQ | PS/2 keyboard key press / release event from host. |
| `0x20` | Host Syscall Gateway | Standard host-services dispatcher (`TRAP 0x20`). |
| `0x21`–`0xFF` | OS / User Vectors | Available for KannaOS kernel software interrupts. |

---

## 12. Host-Service Interface (`TRAP 0x20`)

To access bare-metal input/output devices, KannaOS invokes `TRAP 0x20`. The x86 micro-host intercepts this trap and executes the host service defined in `R0`.

### 12.1 Host Calling Convention
- **Input:**
  - `R0`: Host Function ID
  - `R1`: Argument 1
  - `R2`: Argument 2
  - `R3`: Argument 3
- **Output:**
  - `R0`: Status code (`0` = Success, non-zero = Error Code).
  - Registers `R1`–`R7` preserved unless specified as return parameters.

### 12.2 Defined Host Services

#### `0x01`: `SYS_CONSOLE_PUTC` (Print Character)
- **Inputs:** `R0 = 0x01`, `R1 = ASCII character`, `R2 = VGA Attribute` (e.g., `0x07` = white on black).
- **Behavior:** Writes character to VGA $80 \times 25$ screen at current hardware cursor location. Handles `\n`, `\r`, backspace, and automatic screen scrolling.
- **Return:** `R0 = 0`.

#### `0x02`: `SYS_CONSOLE_GETC` (Read Keyboard Character)
- **Inputs:** `R0 = 0x02`, `R1 = Mode` (`0` = non-blocking poll, `1` = blocking wait).
- **Behavior:** Reads next ASCII character from the host PS/2 keyboard ring buffer.
- **Return:** `R0 = ASCII code` (or `0` if non-blocking and no key is waiting).

#### `0x03`: `SYS_CONSOLE_PUTS` (Print String)
- **Inputs:** `R0 = 0x03`, `R1 = 24-bit pointer to null-terminated string`, `R2 = VGA Attribute`.
- **Behavior:** Streams characters to screen buffer until null terminator (`$00`) is reached.
- **Return:** `R0 = Character count printed`.

#### `0x04`: `SYS_CONSOLE_CLEAR` (Clear Screen)
- **Inputs:** `R0 = 0x04`, `R1 = VGA Clear Attribute` (e.g., `0x1F` = bright white on blue).
- **Behavior:** Fills all 2,000 cells of $80 \times 25$ text buffer with blanks (`0x20`) and sets cursor to $(0,0)$.
- **Return:** `R0 = 0`.

#### `0x05`: `SYS_GET_SYSINFO` (Query Host & Machine Info)
- **Inputs:** `R0 = 0x05`, `R1 = 24-bit pointer to 32-byte destination buffer`.
- **Behavior:** Writes machine metadata:
  - Offset `+0` (4 bytes): Host Magic ID (`0x4B323421` = "K24!")
  - Offset `+4` (4 bytes): Host Version (Major, Minor, Patch, Build)
  - Offset `+8` (4 bytes): Physical RAM detected (in KiB)
  - Offset `+12` (4 bytes): Display geometry (`0x00190050` = 80 cols, 25 rows)
  - Offset `+16` (8 bytes): Host cycle counter / millisecond timer
- **Return:** `R0 = 0`.

#### `0x06`: `SYS_DISK_READ` (Read Sectors)
- **Inputs:** `R0 = 0x06`, `R1 = 24-bit LBA Sector Address`, `R2 = Sector Count`, `R3 = 24-bit Destination Address`.
- **Behavior:** Reads sectors from boot media via host BIOS INT 13h / ATA.
- **Return:** `R0 = 0 on success, error code otherwise`.

#### `0x07`: `SYS_DISK_WRITE` (Write Sectors)
- **Inputs:** `R0 = 0x07`, `R1 = 24-bit LBA Sector Address`, `R2 = Sector Count`, `R3 = 24-bit Source Address`.
- **Behavior:** Writes sectors to storage media.
- **Return:** `R0 = 0 on success, error code otherwise`.

#### `0xFF`: `SYS_HALT_POWEROFF` (Power Off / Shutdown)
- **Inputs:** `R0 = 0xFF`.
- **Behavior:** Shuts down the VirtualBox VM via APM / ACPI or halts the processor.

---

## 13. System Information Block (SIB) Memory Map

Populated at `$000400`–`$000FFF` by the host prior to transferring execution to K24:

```
Address   Size  Field Name          Description
0x000400  4 B   SIB_MAGIC           Signature: 0x4B323421 ("K24!")
0x000404  1 B   SIB_VERSION_MAJ     Host Major Version (e.g. 0x01)
0x000405  1 B   SIB_VERSION_MIN     Host Minor Version (e.g. 0x00)
0x000406  2 B   SIB_RESERVED        Reserved (0x0000)
0x000408  3 B   SIB_RAM_KIB         Total system RAM in KiB (24-bit word)
0x00040B  1 B   SIB_BOOT_DRIVE      BIOS boot drive ID (e.g. 0x00, 0x80)
0x00040C  2 B   SIB_SCREEN_COLS     VGA columns (80 = 0x0050)
0x00040E  2 B   SIB_SCREEN_ROWS     VGA rows (25 = 0x0019)
0x000410  3 B   SIB_KERNEL_ENTRY    Initial PC entry point (0x001000)
0x000413  3 B   SIB_STACK_TOP       Initial SP value (0x100000)
0x000416  26 B  SIB_HOST_BANNER     ASCII identification string
```

---

## 14. Verification Checklist for Milestone 0
- [x] Complete register set defined with unambiguous 4-bit encoding.
- [x] Memory address space strictly byte-addressed ($16\text{ MiB}$).
- [x] Partitions non-overlapping: IVT (`0x000000`), SIB (`0x000400`), Kernel (`0x001000`), Stack (`0x080000`), Dynamic (`0x100000`).
- [x] Stack growth direction explicitly Full-Descending (decrements before push, increments after pop).
- [x] Fixed 24-bit (3-byte) instruction format with unambiguous 48-bit (6-byte) extended format.
- [x] Full opcode table and flag generation formulas specified.
- [x] Trap and host-service interface (`TRAP 0x20`) defined with exact calling conventions.
