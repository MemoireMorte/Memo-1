# Memo-1

A simple 65C02 based computer for fun and learning purpose.

## Technical information

The Memo-1 consists on a 65C02 CPU running at 1Mhz, crudely attached to 32K of ram, 16K of rom, and has a 65C22 via and a 6551 ACIA (NOT the W65C51). The system is thought to have 8k of rom available as extension, and to be linked to a Minitel 1b as terminal.

### Addresses

```
High nibble (A15..A12) | Hex range      | Selection
-----------------------+----------------+-----------------
0000 (0x0)             | 0000 - 0FFF    | RAM
0001 (0x1)             | 1000 - 1FFF    | RAM
0010 (0x2)             | 2000 - 2FFF    | RAM
0011 (0x3)             | 3000 - 3FFF    | RAM
0100 (0x4)             | 4000 - 4FFF    | RAM
0101 (0x5)             | 5000 - 5FFF    | RAM
0110 (0x6)             | 6000 - 6FFF    | RAM
0111 (0x7)             | 7000 - 7FFF    | RAM
-----------------------+----------------+-----------------
1000 (0x8)             | 8000 - 8FFF    | VIA
1001 (0x9)             | 9000 - 9FFF    | ACIA
-----------------------+----------------+-----------------
1010 (0xA)             | A000 - AFFF    | External slot
1011 (0xB)             | B000 - BFFF    | External slot
-----------------------+----------------+-----------------
1100 (0xC)             | C000 - CFFF    | ROM
1101 (0xD)             | D000 - DFFF    | ROM
1110 (0xE)             | E000 - EFFF    | ROM
1111 (0xF)             | F000 - FFFF    | ROM
```

### VIA

The 65C22 VIA is accessible at address $8000 to $8003 and cannot trigger interrupts. It is used to provide 2 Atari CX40 Joysticks ports.

### VIA addresses

```
Port B RW ------------------ $8000
Port A RW ------------------ $8001
Data direction register B -- $8002
Data direction register A -- $8003
Timer 1 low byte ----------- $8004
Timer 1 high byte ---------- $8005
Auxiliary Control Register - $800B
```

Atari 2600 joystick 0 is on VIA Port A bit[0..4] and joystick 1 is on VIA Port B bit[0..4] as follow

```
Up ----- Bit0
Down --- Bit1
Left --- Bit2
Right -- Bit3
Fire --- Bit4
```

Basic function `JOY()` provides the same thing. `JOY(0)` for port A and `JOY(1)` for port B will return a number corresponding to the given port's status, masked on the 5 corresponding bits (this way, bits 5, 6 and 7 are still usable in the future without altering this implementation).  
Sample: 
```BASIC
10 A = JOY(0)
20 IF A = 31 THEN GOTO 10
30 IF A = 30 THEN PRINT "UP"
40 IF A = 29 THEN PRINT "DOWN"
50 IF A = 27 THEN PRINT "LEFT"
60 IF A = 23 THEN PRINT "RIGHT"
70 IF A = 15 THEN PRINT "FIRE"
80 GOTO 10
RUN
```

Basic routine `TONE` plays a square wave tone on Port B bit 7. At 1Mhz here is the equivalence table for each note: 
```
DO 261.63Hz  = 1911
DO# 277.18Hz = 1808
RE 293.66Hz  = 1702
RE# 311.13Hz = 1607
MI 329.63Hz  = 1517
FA 349.23Hz  = 1432
FA# 369.99Hz = 1350
SOL 392.00Hz = 1275
SOL# 415.30Hz= 1203
LA 440Hz     = 1136
LA# 466.16Hz = 1073
SI 493.88Hz  = 1010
```
Play an A or LA 440 for a while then stop with TONE 0: 
```BASIC
10 TONE 1136
20 K = 40
30 FOR I=0 TO K STEP 1
40   PRINT I
50 NEXT I
60 TONE 0
70 END
RUN
```

### ACIA
```
ACIA data register ----- $9000
ACIA status register --- $9001
ACIA command register -- $9002
ACIA control register -- $9003
```

## The menu

Upon startup, the Memo-1 inits the ACIA, the VIA, sends commands to the Minitel to change the baud rate and disable local echo, then presents a simple menu system with several options: press '1' to launch WOZMON (a monitor program by Steve Wozniak for memory examination and modification), press '2' to start MS-BASIC (Microsoft BASIC interpreter), press '3' to execute code from an external ROM slot (this option only appears if an external ROM is detected at address $A000), or press 'A' to view an about screen with system information, license and credits.  
The menu automatically detects an external ROM's presence and adapts the available options accordingly by looking at the first opcode at $A000. If it reads $A0 it assumes there is nothing there (6502 always read high nibble of the address when accessing an address where no hardware responds). If your code has to start with $A0 (LDY) then just add $EA (NOP) before and question your lifestyle, you barbarian (who would start a code by stuffing the Y register?).  
If the start menu detects a ROM in external slot, it will read a personalised name from the last 8 bytes of the rom, from $BFF8 to $BFFF. 
If $BFF8 is $00 or $FF it will skip reading, and just display 'External Slot' in the menu.

## Terminal

This project is made to use a Minitel 1b as terminal. It implements a simple minitel driver for 65C02, assuming you are using the 6551 ACIA chip as UART (NOT the W65C51, which has 2 hardware incompatibilities with the Minitel).  
The Minitel driver is the src/minitel.s file (yes I know, I'm the exentric one of the family).

## Assemble the code

The code is built to use ca65 and ld65 assembler and linker.  
To assemble the code yourself, make sure you have both binaries in your path, or adapt the following commands. 


First make sure you have an out directory next to the src. If you cloned this repository you should have it already as I wanted to share a binary release at least. 

```BASH
cd src
ca65 -D memo msbasic.s -o ../out/memo.o &&
ld65 -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl
```

## Licenses & credits

A 65C02 chip set based computer, for fun and for learning purposes.  
By Benoit Aveline, aka Memoire Morte  
(c) 2025 - Creative Commons BY-NC

Special thanks to:
 - [Ben Eater](https://eater.net/6502) for his 6502 computer design and tutorials - *CC-BY License*
 - [Ian Ward](https://www.youtube.com/@IanWard1) for his YouTube videos on 2004 lcd and 555 timer - *No license found*
Current source code is based on:
 - Wozmon by Steve Wozniak - *(c) 1976 Apple (before code IP even exist)*
 - [BASIC-M6502](https://github.com/microsoft/BASIC-M6502) by Weiland & Gates - *(c) Microsoft - MIT License*
 - [MS-BASIC disassembly](https://github.com/mist64/msbasic) by [Michael Steil](https://github.com/mist64) - *2-clause BSD License*