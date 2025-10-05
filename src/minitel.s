.setcpu "65C02"
.segment "MINITEL"

; Minitel Demo
; Simple demo to show some functions of the Minitel terminal controlled via a 6502

SPEED300 = $52 ; 300 baud
SPEED1200 = $64 ; 1200 baud
SPEED4800 = $76 ; 4800 baud
SPEED9600 = $7F ; 9600 baud only for Minitel 2

; Control codes
ESC             = $1B    ; Escape character
FF              = $0C    ; Form Feed (clear screen)
RS              = $1E    ; Record Separator (home position)
US              = $1F    ; Unit Separator (position cursor)

; Minitel Protocol codes
PRO1           = $39    ; PRO1 command
PRO2           = $3A    ; PRO2 command
PRO3           = $3B    ; PRO3 command

; Minitel special commands
FNCT_STOP       = $6A    ; STOP function code
FNCT_START      = $69    ; START function code
ROULEAU         = $43    ; Scroll mode command

; Minitel routing codes
AIGUILLAGE_OFF  = $60    ; Routing OFF command
AIGUILLAGE_ON   = $61    ; Routing ON command
EMISSION_CLAVIER = $51   ; Keyboard as emitter
RECEPTION_MODEM = $5A    ; Modem as receiver

RST  = $7F  ; Reset command
CON  = $11  ; Cursor ON
COFF = $14  ; Cursor OFF
SO   = $0E  ; Shift Out : Accès au jeu G1. => Mode semi-graphique
SI   = $0F  ; Shift In : Accès au jeu G0.  => Mode alphanumérique
; Graphical characters in semi-graphical mode
; The case is made of 2x3 blocks, each block can be either empty or filled.
; The blocks are numbered as follows:
;  0 1
;  2 3
;  4 6
; Each block corresponds to a bit in the character byte where bit 0 is block 0, bit 1 is block 1, etc.
; Bit 5 is always 1 (except for full character) and 7 is always 0.
; Example: 0x5F = %01011111 will display all blocks filled.
LEFT_HALF_GRAPHICAL_CHAR = $35 ; %00110101 : Character to display a left half graphical char in semi-graphical mode
RIGHT_HALF_GRAPHICAL_CHAR = $6A ; %01101010 : Character to display a right half graphical char in semi-graphical mode
PLAIN_GRAPHICAL_CHAR = $5F ; %01011111 : Character to display a plain graphical char in semi-graphical mode


;-----------------------------------------------------
; Delay loop to allow Minitel time to process command
;-----------------------------------------------------
DOUBLE_DELAY:    
; just a dumb loop for now
    ldx #$FF
@loop1:
    ldy #$FF
@loop2:
    dey
    bne @loop2
    dex
    bne @loop1
    rts

;-----------------------------------------------------
; Reset the Minitel
;-----------------------------------------------------
RESET_MINITEL:
    ; ESC 0x39 0x7F
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE

    ; Send PRO1 sequence
    lda #PRO1
    jsr SEND_BYTE

    ; Send PRO1 sequence
    lda #RST
    jsr SEND_BYTE

    rts

;-----------------------------------------------------
; Send command to Minitel to switch to 1200 baud
;-----------------------------------------------------
SEND_1200_COMMAND:
    ; ESC 0x3A 0x6B 0x76
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE
    
    ; Send PRO2 sequence
    lda #PRO2
    jsr SEND_BYTE
    
    ; Send PROG command
    lda #$6B            ; PROG
    jsr SEND_BYTE

    ; Send 1200 baud parameter
    lda #SPEED1200      ; 1200 baud
    jsr SEND_BYTE

    jsr DOUBLE_DELAY      ; Wait a bit for Minitel to process command
    
    rts

;-----------------------------------------------------
; Send command to Minitel to switch to 4800 baud
;-----------------------------------------------------
SEND_4800_COMMAND:
    ; ESC 0x3A 0x6B 0x76
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE
    
    ; Send PRO2 sequence
    lda #PRO2
    jsr SEND_BYTE
    
    ; Send PROG command
    lda #$6B            ; PROG
    jsr SEND_BYTE
    
    ; Send 4800 baud parameter
    lda #SPEED4800      ; 4800 baud
    jsr SEND_BYTE

    jsr DOUBLE_DELAY      ; Wait a bit for Minitel to process command
    
    rts

;-----------------------------------------------------
; Send command to Minitel to disable echo
;-----------------------------------------------------
DISABLE_ECHO:
    ; ESC 0x3B 0x60 0x5A 0x51
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE
    
    ; Send PRO3 sequence
    lda #PRO3
    jsr SEND_BYTE
    
    ; Send AIGUILLAGE_OFF command
    lda #AIGUILLAGE_OFF ; Routing OFF (0x60)
    jsr SEND_BYTE
    
    ; Send RECEPTION_MODEM parameter
    lda #RECEPTION_MODEM ; Modem as receiver (0x5A)
    jsr SEND_BYTE
    
    ; Send EMISSION_CLAVIER parameter
    lda #EMISSION_CLAVIER ; Keyboard as emitter (0x51)
    jsr SEND_BYTE

    jsr DOUBLE_DELAY      ; Wait a bit for Minitel to process command
    
    rts

;-----------------------------------------------------
; Send command to Minitel to enable scroll mode
;-----------------------------------------------------
SCROLL_MODE:
    ; ESC 0x3A 0x69 0x43
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE
    
    ; Send PRO2 sequence
    lda #PRO2
    jsr SEND_BYTE
    
    ; Send START command
    lda #FNCT_START     ; START (0x69)
    jsr SEND_BYTE
    
    ; Send ROULEAU parameter
    lda #ROULEAU        ; ROULEAU (0x43)
    jsr SEND_BYTE

    jsr DOUBLE_DELAY    ; Wait a bit for Minitel to process command
    
    rts
    
;-----------------------------------------------------
; Send command to Minitel to enable page mode
;-----------------------------------------------------
PAGE_MODE:
    ; ESC 0x3A 0x69 0x43
    ; Send ESC
    lda #ESC
    jsr SEND_BYTE
    
    ; Send PRO2 sequence
    lda #PRO2
    jsr SEND_BYTE
    
    ; Send STOP command
    lda #FNCT_STOP      ; STOP (0x6A)
    jsr SEND_BYTE
    
    ; Send ROULEAU parameter
    lda #ROULEAU        ; ROULEAU (0x43)
    jsr SEND_BYTE

    jsr DOUBLE_DELAY    ; Wait a bit for Minitel to process command
    
    rts
    
;-----------------------------------------------------
; Enable graphic mode
;-----------------------------------------------------
GRAPHIC_MODE:
    lda #SO
    jsr SEND_BYTE
    rts
    
;-----------------------------------------------------
; Enable text mode
;-----------------------------------------------------
TEXT_MODE:
    lda #SI
    jsr SEND_BYTE
    rts
    
;-----------------------------------------------------
; Basic screen and text functions
;-----------------------------------------------------

; Clear screen (FF) - Legacy simple method
CLEAR_SCREEN_SIMPLE:
    lda #FF
    jsr SEND_BYTE
    rts

; Clear screen using CSI sequence - Clear entire screen (0x1B 0x5B 2 J)
; Equivalent to clearScreen() in the C++ library
CLEAR_SCREEN:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    lda #$32           ; '2' parameter
    jsr SEND_BYTE
    lda #$4A           ; 'J' command
    jsr SEND_BYTE
    rts

; Clear screen from cursor to end of screen (0x1B 0x5B J)
; Equivalent to clearScreenFromCursor() in the C++ library
CLEAR_SCREEN_FROM_CURSOR:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    lda #$4A           ; 'J' command
    jsr SEND_BYTE
    rts

; Clear screen from beginning to cursor position (0x1B 0x5B 1 J)
; Equivalent to clearScreenToCursor() in the C++ library
CLEAR_SCREEN_TO_CURSOR:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    lda #$31           ; '1' parameter
    jsr SEND_BYTE
    lda #$4A           ; 'J' command
    jsr SEND_BYTE
    rts

; Clear line from cursor to end of line (0x1B 0x5B K)
; Equivalent to clearLineFromCursor() in the C++ library
CLEAR_LINE_FROM_CURSOR:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    ; No parameter needed (0 is default)
    lda #$4B           ; 'K' command
    jsr SEND_BYTE
    rts

; Clear line from beginning to cursor position (0x1B 0x5B 1 K)
; Equivalent to clearLineToCursor() in the C++ library
CLEAR_LINE_TO_CURSOR:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    lda #$31           ; '1' parameter
    jsr SEND_BYTE
    lda #$4B           ; 'K' command
    jsr SEND_BYTE
    rts

; Clear entire line (0x1B 0x5B 2 K)
; Equivalent to clearLine() in the C++ library
CLEAR_LINE:
    jsr SEND_CSI       ; Send 0x1B 0x5B sequence
    lda #$32           ; '2' parameter
    jsr SEND_BYTE
    lda #$4B           ; 'K' command
    jsr SEND_BYTE
    rts

;-----------------------------------------------------
; Cursor functions
;-----------------------------------------------------

; Move cursor to home position (RS)
CURSOR_HOME:
    lda #RS
    jsr SEND_BYTE
    rts

; Enable cursor (CON)
CURSOR_ON:
    lda #CON
    jsr SEND_BYTE
    rts

; Disable cursor (COFF)
CURSOR_OFF:
    lda #COFF
    jsr SEND_BYTE
    rts

; Move cursor left by N positions
; Input: A register contains number of positions (0-80)
MOVE_CURSOR_LEFT:
    pha
    jsr SEND_CSI
    pla
    jsr WRITE_BYTES_P
    lda #$44
    jsr SEND_BYTE
    rts

; Move cursor right by N positions
; Input: A register contains number of positions (0-80)
MOVE_CURSOR_RIGHT:
    pha
    jsr SEND_CSI
    pla
    jsr WRITE_BYTES_P
    lda #$43
    jsr SEND_BYTE
    rts

; Move cursor down by N positions
; Input: A register contains number of positions (0-26)
MOVE_CURSOR_DOWN:
    pha
    jsr SEND_CSI
    pla
    jsr WRITE_BYTES_P
    lda #$42
    jsr SEND_BYTE
    rts

; Move cursor up by N positions
; Input: A register contains number of positions (0-26)
MOVE_CURSOR_UP:
    pha
    jsr SEND_CSI
    pla
    jsr WRITE_BYTES_P
    lda #$41
    jsr SEND_BYTE
    rts

; Move cursor to position (row, col)
; Input: X = column (1-80), Y = row (1-26)
; Modifies A register
MOVE_CURSOR_TO_XY:
    phx
    phy
    jsr SEND_CSI
    phx
    tya
    jsr WRITE_BYTES_P
    lda #$3B
    jsr SEND_BYTE
    plx
    txa
    jsr WRITE_BYTES_P
    lda #$48
    jsr SEND_BYTE
    ply
    plx
    rts

SEND_CSI:
    lda #ESC
    jsr SEND_BYTE
    lda #$5B
    jsr SEND_BYTE
    rts

;-----------------------------------------------------
; Send byte to Minitel via ACIA
;-----------------------------------------------------
SEND_BYTE:
    sta ACIA_DATA           ; Output character.
    pha                     ; Save A.
@tx_wait:
    lda ACIA_STATUS         ; Check status register
    and #$10                ; Check TDRE (bit 4 TX Buffer Empty flag)
    beq @tx_wait            ; If not set, keep waiting
    pla                     ; Restore A.
    rts                     ; Return.

;-----------------------------------------------------
; Write parameter bytes for Minitel commands
; Input: A register contains the parameter value (0-99)
; Converts number to ASCII representation for Minitel
; For values ≤9, sends single digit
; For values >9, sends two digits
;-----------------------------------------------------
WRITE_BYTES_P:
    cmp #10                 ; Compare with 10
    bcc @single_digit       ; If less than 10, branch to @single_digit
    
    ; Handle two digits (10-99)
    pha                     ; Save original value
    
    ; Divide by 10 to get tens digit
    ldx #0                  ; Initialize quotient (tens digit) to 0
@div_loop:
    cmp #10                 ; Compare with 10
    bcc @div_done            ; If less than 10, division is done
    sec                     ; Set carry flag before subtraction
    sbc #10                 ; Subtract 10
    inx                     ; Increment quotient (tens digit)
    jmp @div_loop            ; Continue dividing
@div_done:
    pha                     ; Save remainder (ones digit)
    
    ; Send tens digit
    txa                     ; Get tens digit
    clc
    adc #$30                ; Convert to ASCII
    jsr SEND_BYTE           ; Send tens digit
    
    ; Send ones digit
    pla                     ; Get ones digit
    clc
    adc #$30                ; Convert to ASCII
    jsr SEND_BYTE           ; Send ones digit
    pla                     ; Restore original A value (cleanup stack)
    rts                     ; Return to caller
@single_digit:
    ; Handle single digit (0-9)
    clc
    adc #$30                ; Convert to ASCII (add 0x30)
    jsr SEND_BYTE           ; Send the byte
    rts                     ; Return to caller
