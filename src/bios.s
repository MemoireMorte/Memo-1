.setcpu "65C02"
.debuginfo

.zeropage
                .org ZP_START0
READ_PTR:       .res 1
WRITE_PTR:      .res 1

.segment "INPUT_BUFFER"
INPUT_BUFFER:      .res $100

.segment "BIOS"

; ============================================
; --- ACIA Control Register Bits ---
; Bit 7: 0=1 stop bit, 1=2 stop bits
; Bits 6-5: Word length
;   65
;   00 = 8 bits
;   01 = 7 bits
;   10 = 6 bits
;   11 = 5 bits
; Bit 4: Receiver Clock Source
;   0 = external
;   1 = baud rate
; Bits 3-0: Baud rate
;   0000 = 16x
;   0001 = 50
;   0010 = 75
;   0011 = 109.92
;   0100 = 134.58
;   0101 = 150
;   0110 = 300
;   0111 = 600
;   1000 = 1200
;   1001 = 1800
;   1010 = 2400
;   1011 = 3600
;   1100 = 4800
;   1101 = 7200
;   1110 = 9600
;   1111 = 19200
;
; example: 1 stop bit, 7 bits, rcs: baud rate, baud rate: 4800 = %00111100 for minitel 7E1
; example: 1 stop bit, 8 bits, rcs: baud rate, baud rate: 9600 = %00011110
ACIA_CTRL_1STOP = %00000000  ; 1 stop bit
ACIA_CTRL_2STOP = %10000000  ; 2 stop bits

ACIA_CTRL_5BIT  = %01100000  ; 5 data bits
ACIA_CTRL_6BIT  = %01000000  ; 6 data bits
ACIA_CTRL_7BIT  = %00100000  ; 7 data bits
ACIA_CTRL_8BIT  = %00000000  ; 8 data bits

ACIA_CTRL_RCSEXT   = %00000000  ; external clock source
ACIA_CTRL_RCSBAUD  = %00010000  ; baud rate clock source

ACIA_CTRL_BAUD16X  = %00000000  ; 16x baud rate
ACIA_CTRL_BAUD50   = %00000001  ; 50 baud
ACIA_CTRL_BAUD75   = %00000010  ; 75 baud
ACIA_CTRL_BAUD109  = %00000011  ; 109.92 baud
ACIA_CTRL_BAUD134  = %00000100  ; 134.58 baud
ACIA_CTRL_BAUD150  = %00000101  ; 150 baud
ACIA_CTRL_BAUD300  = %00000110  ; 300 baud
ACIA_CTRL_BAUD600  = %00000111  ; 600 baud
ACIA_CTRL_BAUD1200 = %00001000  ; 1200 baud
ACIA_CTRL_BAUD1800 = %00001001  ; 1800 baud
ACIA_CTRL_BAUD2400 = %00001010  ; 2400 baud
ACIA_CTRL_BAUD3600 = %00001011  ; 3600 baud
ACIA_CTRL_BAUD4800 = %00001100  ; 4800 baud
ACIA_CTRL_BAUD7200 = %00001101  ; 7200 baud
ACIA_CTRL_BAUD9600 = %00001110  ; 9600 baud
ACIA_CTRL_BAUD19200= %00001111  ; 19200 baud
; ============================================

; --- ACIA Command Register Bits ---
; Bits 7-6: Parity Mode Control (should be disabled on W65C51N)
;  00 = odd parity
;  01 = even parity
;  10 = forced 1 parity
;  11 = forced 0 parity
;   Any combination is acceptable when parity is disabled
; Bit 5: Parity Mode Enable
;   0 = disabled (should always be 0 on W65C51N)
;   1 = enabled
; Bit 4: Receiver Echo Mode
;   0 = disabled
;   1 = enabled (Transmitter echoes received data, bits 2-3 must be 0)
; Bits 3-2: Transmitter Interrupt Control / Ready to Send (RTSB) line
;   32
;   00 = RTSB low, transmitting interrupt disabled
;   01 = RTSB low, transmitting interrupt enabled
;   10 = RTSB high, transmitting interrupt disabled
;   11 = RTSB low, transmits break, transmitting interrupt disabled
; Bit 1: Receiver Interrupt Control
;   0 = receiver interrupt enabled (when bit 0 is 1)
;   1 = receiver interrupt disabled
; Bit 0: Data Terminal Ready (DTRB) line
;   0 = DTRB high (not ready), all interrupts disabled
;   1 = DTRB low (ready), enables selected interrupts
;
; example: Parity  enabled, echo off, RTSB high with TX interrupt disabled, RX interrupt disabled, DTR ready = %01101011 for Minitel 7E1
; example: Parity disabled, echo off, RTSB high with TX interrupt disabled, RX interrupt disabled, DTR ready = %00001011

ACIA_CMD_ODDPAR   = %00000000
ACIA_CMD_EVENPAR  = %01000000
ACIA_CMD_F1PAR    = %10000000
ACIA_CMD_F0PAR    = %11000000

ACIA_CMD_PAREN    = %00100000
ACIA_CMD_PARDIS   = %00000000

ACIA_CMD_ECHOEN   = %00010000
ACIA_CMD_ECHODIS  = %00000000

ACIA_CMD_RTSB0    = %00000000
ACIA_CMD_RTSB1    = %00000100
ACIA_CMD_RTSB2    = %00001000
ACIA_CMD_RTSBBRK  = %00001100

ACIA_CMD_RXINTEN  = %00000000
ACIA_CMD_RXINTDIS = %00000010

ACIA_CMD_DTRB0    = %00000000
ACIA_CMD_DTRB1    = %00000001

; ============================================

; --- ACIA Status Register Bits ---
; Bit 7: Interrupt (IRQ)
;   0 = no interrupt
;   1 = interrupt has occurred (cleared when status register is read)
; Bit 6: Data Set Ready (DSRB)
;   0 = DSRB line is low (true condition)
;   1 = DSRB line is high (false condition)
; Bit 5: Data Carrier Detect (DCDB)
;   0 = DCDB line is low (true condition)
;   1 = DCDB line is high (false condition)
; Bit 4: Transmitter Data Register Empty (TDRE)
;   Always 1 on W65C51N (TSR is loaded when TDR is written)
;   Note: Use delay loops instead of polling this bit
; Bit 3: Receiver Data Register Full (RDRF)
;   0 = receiver register empty
;   1 = data has been transferred to receiver register
; Bit 2: Overrun
;   0 = no overrun
;   1 = overrun has occurred (self-clearing after reading data register)
; Bit 1: Framing Error
;   0 = no framing error
;   1 = framing error has occurred (self-clearing after reading data register)
; Bit 0: Parity Error
;   Not used on W65C51N (parity is never enabled)
;
; Note: Bits 0-2 are automatically cleared after reading the receiver data register
; Note: Bits 5-6 are updated when status register is read (can trigger new interrupt)
; ============================================

ACIA_DATA	= $9000
ACIA_STATUS	= $9001
ACIA_CMD	= $9002
ACIA_CTRL	= $9003

ACIA_CMD_PDIS_EOFF = ACIA_CMD_DTRB1 | ACIA_CMD_RXINTEN | ACIA_CMD_RTSB2 | ACIA_CMD_ECHODIS | ACIA_CMD_PARDIS | ACIA_CMD_ODDPAR
;               00000001         00000000            00001000         00000000          00000000           00000000
;ACIA_CMD_PDIS_EOFF = $09 = %00001001
ACIA_CMD_PEN_EOFF = ACIA_CMD_DTRB1 | ACIA_CMD_RXINTEN | ACIA_CMD_RTSB2 | ACIA_CMD_ECHODIS | ACIA_CMD_PAREN | ACIA_CMD_EVENPAR
;               00000001         00000000            00001000         00000000          00100000           01000000
;ACIA_CMD_PEN_EOFF = $69 = %01101001

ACIA_CTRL_1S8B_19200 = ACIA_CTRL_1STOP | ACIA_CTRL_8BIT | ACIA_CTRL_RCSBAUD | ACIA_CTRL_BAUD19200
;                       00000000         00000000          00010000           00001111
;ACIA_CTRL_1S8B_19200 = $1F = %00011111
ACIA_CTRL_1S7B_4800 = ACIA_CTRL_1STOP | ACIA_CTRL_7BIT | ACIA_CTRL_RCSBAUD | ACIA_CTRL_BAUD4800
;                       00000000         00100000          00010000           00001100
;ACIA_CTRL_1S7B_4800 = $3C = %00111100
ACIA_CTRL_1S7B_1200 = ACIA_CTRL_1STOP | ACIA_CTRL_7BIT | ACIA_CTRL_RCSBAUD | ACIA_CTRL_BAUD1200
;                       00000000         00100000          00010000           00001000
;ACIA_CTRL_1S7B_1200 = $38 = %00111000

; VIA addresses
VIA_PORTB = $8000     ; Port B address
VIA_PORTA = $8001     ; Port A address
VIA_DDRB  = $8002     ; Data direction register B ; output if bit=1
VIA_DDRA  = $8003     ; Data direction register A ; output if bit=1

VIA_T1CL  = $8004     ; Timer 1 low byte
VIA_T1CH  = $8005     ; Timer 1 high byte
VIA_ACR   = $800B     ; Audio control register

BTN_UP = %00000001    ; Up button mask
BTN_DOWN = %00000010  ; Down button mask
BTN_LEFT = %00000100  ; Left button mask
BTN_RIGHT = %00001000 ; Right button mask
BTN_FIRE = %00010000  ; Fire button mask

; test button input 
; instead of PEEK(32769)
GET_JOY_A_INPUT:
                lda VIA_PORTA       ; Read port A
                and #%00011111      ; Mask to get lower 5 bits
                rts                 ; Return with result in A

GET_JOY_B_INPUT:
                lda VIA_PORTB       ; Read port B
                and #%00011111      ; Mask to get lower 5 bits
                rts

; Test program for JOY routine on port A
; 10 A = JOY(0)
; 20 IF A = 31 THEN GOTO 10
; 30 IF A = 30 THEN PRINT "UP"
; 40 IF A = 29 THEN PRINT "DOWN"
; 50 IF A = 27 THEN PRINT "LEFT"
; 60 IF A = 23 THEN PRINT "RIGHT"
; 70 IF A = 15 THEN PRINT "FIRE"
; 80 GOTO 10
; RUN

JOY:
                jsr GETADR         ; Get address of parameter
                lda LINNUM
                ora LINNUM+1       ; OR low and high bytes
                beq @param_is_zero ; Branch if parameter is 0
                jsr GET_JOY_B_INPUT
                jmp @return_value
    
@param_is_zero:
                jsr GET_JOY_A_INPUT ; Get all 5 bits
    
@return_value:
                tay                 ; Move to Y for SNGFLT
                jmp SNGFLT          ; Convert to floating point and return

; Play a tone on the speaker at the frequency in X (low) and Y (high)

PLAY_TONE:
                pha
                txa
                sta VIA_T1CL
                tya
                sta VIA_T1CH

                lda #$C0   ; Timer 1 in continuous mode, square wave, count at 1MHz
                sta VIA_ACR
                pla
                rts

STOP_TONE:
                pha
                lda #0
                sta VIA_ACR   ; Disable timer
                pla
                rts

; Frequencies for notes (approximate, with 1MHz clock)
; #$777 = DO 261.63Hz ; 1000000 / 261.63 = 3822.66 ; 3822.66 / 2 = 1911.33 = $777
; #$710 = DO# 277.18Hz ; 1000000 / 277.18 = 3615.75 ; 3615.75 / 2 = 1807.87 = $710
; #$6A6 = RE 293.66Hz ; 1000000 / 293.66 = 3405.06 ; 3405.06 / 2 = 1702.53 = $6A6
; #$647 = RE# 311.13Hz ; 1000000 / 311.13 = 3214.29 ; 3214.29 / 2 = 1607.14 = $647
; #$5EC = MI 329.63Hz ; 1000000 / 329.63 = 3033.96 ; 3033.96 / 2 = 1516.98 = $5EC
; #$598 = FA 349.23Hz ; 1000000 / 349.23 = 2864.66 ; 2864.66 / 2 = 1432.33 = $598
; #$546 = FA# 369.99Hz ; 1000000 / 369.99 = 2700.00 ; 2700.00 / 2 = 1350.00 = $546
; #$4FB = SOL 392.00Hz ; 1000000 / 392.00 = 2551.02 ; 2551.02 / 2 = 1275.51 = $4FB
; #$4B3 = SOL# 415.30Hz ; 1000000 / 415.30 = 2405.88 ; 2405.88 / 2 = 1202.94 = $4B3
; #$470 = LA 440Hz ; 1000000 / 440 = 2272.73 ; 2272.73 / 2 = 1136.36 = $470
; #$431 = LA# 466.16Hz ; 1000000 / 466.16 = 2145.45 ; 2145.45 / 2 = 1072.73 = $431
; #$3F2 = SI 493.88Hz ; 1000000 / 493.88 = 2020.41 ; 2020.41 / 2 = 1010.20 = $3F2

PLAY_TONE_DO:
                ldx #$77
                ldy #$07
                jmp PLAY_TONE
                rts
PLAY_TONE_DO_SHARP:
                ldx #$10
                ldy #$07
                jmp PLAY_TONE
                rts
PLAY_TONE_RE:
                ldx #$A6
                ldy #$06
                jmp PLAY_TONE
                rts
PLAY_TONE_RE_SHARP:
                ldx #$47
                ldy #$06
                jmp PLAY_TONE
                rts
PLAY_TONE_MI:
                ldx #$EC
                ldy #$05
                jmp PLAY_TONE
                rts
PLAY_TONE_FA:
                ldx #$98
                ldy #$05
                jmp PLAY_TONE
                rts
PLAY_TONE_FA_SHARP:
                ldx #$46
                ldy #$05
                jmp PLAY_TONE
                rts
PLAY_TONE_SOL:
                ldx #$FB
                ldy #$04
                jmp PLAY_TONE
                rts
PLAY_TONE_SOL_SHARP:
                ldx #$B3
                ldy #$04
                jmp PLAY_TONE
                rts
PLAY_TONE_LA:
                ldx #$70
                ldy #$04
                jmp PLAY_TONE
                rts
PLAY_TONE_LA_SHARP:
                ldx #$31
                ldy #$04
                jmp PLAY_TONE
                rts
PLAY_TONE_SI:
                ldx #$F2
                ldy #$03
                jmp PLAY_TONE
                rts


LOAD:
                rts

SAVE:
                rts


; Input a character from the serial interface.
; On return, carry flag indicates whether a key was pressed
; If a key was pressed, the key value will be in the A register
;
; Modifies: flags, A, X
MONRDKEY:
CHRIN:
                phx
                jsr     BUFFER_SIZE
                beq     @no_keypressed
                jsr     READ_BUFFER
                jsr     CHROUT			; echo
                plx
                sec
                rts
@no_keypressed:
                plx
                clc
                rts


; Output a character (from the A register) to the serial interface.
;
; Modifies: flags
MONCOUT:
CHROUT:
                pha
                sta     ACIA_DATA
@txwait:        lda     ACIA_STATUS
                and     #$10
                beq     @txwait
                pla
                rts

; Initialize the input buffer
; Modifies: flags, A
CLEAR_BUFFER:
INIT_BUFFER:
                lda     READ_PTR
                sta     WRITE_PTR
                rts
; Write a character (from A) to the input buffer
; Modifies: flags, X
WRITE_BUFFER:
                ldx     WRITE_PTR
                sta     INPUT_BUFFER, x
                inc     WRITE_PTR
                rts

; Read a character from the input buffer to A
; Modifies: flags, A, X
READ_BUFFER:
                ldx     READ_PTR
                lda     INPUT_BUFFER, x
                inc     READ_PTR
                rts
; Return in A the number of unread characters in the input buffer
; Modifies: flags, A
BUFFER_SIZE:
                lda     WRITE_PTR
                sec
                sbc     READ_PTR
                rts

; Interrupt request handler
IRQ:
                pha
                phx
                lda     ACIA_STATUS
                lda     ACIA_DATA
                jsr     WRITE_BUFFER
                plx
                pla
                rti

.include "minitel.s"
.include "start_menu.s"
.include "wozmon.s"

.segment "RESETVEC"
                .word   $0F00           ; NMI vector
                .word   RESET           ; RESET vector
                .word   IRQ             ; IRQ vector

