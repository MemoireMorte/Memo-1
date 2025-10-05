# Memo-1
A simple 65C02 based computer for fun and learning purpose.

(c) MemoireMorte - Creative Commons BY-NC

## Assemble the code
The code is built to use ca65 and ld65 assembler and linker. 
To assemble the code yourself, make sure you have both binaries in your path, or adapt the following commands. 


First make sure you have an out directory next to the src. If you cloned this repository you should have it already as I wanted to share a binary release at least. 
```
cd src
ca65 -D memo msbasic.s -o ../out/memo.o &&
ld65 -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl
```

## Terminal
This project is made to use a Minitel 1b as terminal. It implements a simple minitel driver for 65C02, assuming you are using the 6551 ACIA chip as UART (NOT the W65C51, which has 2 hardware incompatibilities with the Minitel).

The Minitel driver is the src/minitel.s file ( yes, original! ).