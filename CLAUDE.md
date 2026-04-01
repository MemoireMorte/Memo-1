# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Memo-1 is a 65C02-based single-board computer (SBC). The firmware is a port of Microsoft BASIC for 6502 (based on Michael Steil's disassembly) adapted for the Memo-1 hardware, with a custom boot menu, Minitel terminal driver, and KCS cassette save routines.

**Hardware**: WDC 65C02 @ 1 MHz, 32K RAM ($0000–$7FFF), 16K ROM ($C000–$FFFF)  
**I/O**: 65C22 VIA @ $8000 (joysticks), 6551 ACIA @ $9000 (Minitel serial terminal)  
**Extension slot**: $A000–$BFFF (external ROM cards; $A000–$A007 = 8-byte detection header)

## Build

The toolchain uses the cc65 suite. The binaries live one level above `src/`:

```sh
cd src
../ca65.exe -D memo msbasic.s -o ../out/memo.o
../ld65.exe -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl
```

Or just run the build script:

```sh
cd src && bash make.sh
```

Output: `out/memo.bin` (ROM image), `out/memo.lbl` (symbol map).

## Regression Testing

`regress.sh` rebuilds all known BASIC variants and diffs them byte-for-byte against reference binaries. It requires a pre-built `orig/` directory populated with known-good `.bin` files:

```sh
cd src && bash regress.sh
```

## Architecture

### Boot Sequence

```
Reset vector → BIOS init (ACIA/VIA) → Minitel protocol init → Boot menu
```

Boot menu lets the user choose: WOZ Monitor, MS-BASIC, or External ROM.

### Memory Map

| Range         | Contents                          |
|---------------|-----------------------------------|
| $0000–$00FF   | Zero page (BASIC variables)       |
| $0300–$03FF   | Input buffer                      |
| $0400–$7FFF   | RAM (BASIC programs/data)         |
| $8000–$8003   | 65C22 VIA (joystick ports A/B)    |
| $9000–$9003   | 6551 ACIA (Minitel serial)        |
| $A000–$BFFF   | External ROM slot                 |
| $C000–$EFFF   | MS-BASIC (12K)                    |
| $EF00–$F1FF   | Minitel driver                    |
| $F200–$FDFF   | Boot menu                         |
| $FE00–$FFFD   | WOZ Monitor                       |
| $FFFA–$FFFF   | Interrupt/reset vectors           |

### Source File Roles

- `msbasic.s` — Top-level file; `.include`s every other module. This is the only file passed to ca65.
- `defines_memo.s` — Memo-1-specific constants: zero page layout, screen width, KCS ZP block (`$F4–$F9`).
- `defines.s` — Master `#define` list for all BASIC variants; controls conditional assembly throughout.
- `bios.s` — ACIA/VIA initialisation and low-level serial I/O primitives.
- `minitel.s` — Full Minitel 1B terminal driver: baud rate negotiation, semigraphic mode, cursor commands.
- `start_menu.s` — Boot menu with external ROM auto-detection.
- `kcs.s` — KCS (Kansas City Standard) 300 baud cassette save via extension slot (`$B000`).
- `sound.s` / `tone.s` — Audio output via VIA port B bit 7.
- `memo.cfg` — ld65 linker script defining all segments and their addresses.

### Multi-Platform BASIC

The repository also contains assembly sources for 9 historical BASIC variants (Commodore 1/2, AppleSoft, KIM, AIM-65, SYM-1, OSI, MicroTAN, KBD). Each variant has its own `defines_<name>.s` and `<name>.cfg`. Only the `memo` target is relevant for Memo-1 development; the others are for regression testing against original ROMs.

### KCS Timing Constraint

The delay loops in `kcs.s` (`KCS_HALF_1200` and `KCS_HALF_2400`) are cycle-exact at 1 MHz. **If a `BNE @delay` branch crosses a page boundary, it takes 4 cycles instead of 3, silently breaking the output frequency.** When changing the KCS segment address in `memo.cfg`, either align to a page boundary or verify both `@delay` labels and their `BNE` instructions are on the same page.

### Zero Page Layout

Zero page is divided into four blocks for BASIC variables (`ZP_START0/1/2/3`) plus Memo-1 extras. KCS variables occupy `$F4–$F9` (`ZP_KCS_START`), just below `STACK_TOP` at `$FA`.
