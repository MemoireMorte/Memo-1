# Memo-1
A simple 65C02 based computer for fun and learning purpose.

(c) MemoireMorte - Creative Commons BY-NC

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
```
Atari 2600 joystick 0 is on VIA Port A bit[0..4] and joystick 1 is on VIA Port B bit[0..4] as follow
```
Up ----- Bit0
Down --- Bit1
Left --- Bit2
Right -- Bit3
Fire --- Bit4
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

The menu automatically detects an external ROM's presence and adapts the available options accordingly by looking at the first opcode at $A000. If it reads 0xA0 it assumes there is nothing there (6502 always read high nibble of the address when accessing an address where no hardware responds). If your code has to start with 0xA0 (LDY) then just add 0xEA (NOP) before and question your lifestyle, you barbarian (who would start a code by stuffing the Y register?).

## Terminal
This project is made to use a Minitel 1b as terminal. It implements a simple minitel driver for 65C02, assuming you are using the 6551 ACIA chip as UART (NOT the W65C51, which has 2 hardware incompatibilities with the Minitel).

The Minitel driver is the src/minitel.s file ( yes, original! ).

## Assemble the code
The code is built to use ca65 and ld65 assembler and linker. 
To assemble the code yourself, make sure you have both binaries in your path, or adapt the following commands. 


First make sure you have an out directory next to the src. If you cloned this repository you should have it already as I wanted to share a binary release at least. 
```
cd src
ca65 -D memo msbasic.s -o ../out/memo.o &&
ld65 -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl
```
