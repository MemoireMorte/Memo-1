.setcpu "65C02"
.zeropage
                .org ZP_START3A
string_ptr:     .res 2

.segment "MENU"

MEMOART1:
    .asciiz "     __ __                        _ "
MEMOART2:
    .asciiz "    |  \  \ ___ ._ _ _  ___  ___ / |"
MEMOART3:
    .asciiz "    |     |/ ._>| ' ' |/ . \|___|| |"
MEMOART4:
    .asciiz "    |_|_|_|\___.|_|_|_|\___/     |_|"

MENU_WOZMON_MSG:
    .asciiz "1- WOZMON"
MENU_BASIC_MSG:
    .asciiz "2- MS-BASIC"
MENU_EXTERNAL_ROM_MSG:
    .asciiz "3- "
MENU_EXTERNAL_ROM_NAME_MSG:
    .asciiz "External Slot"
MENU_ABOUT_MSG:
    .asciiz "A- About"
MENU_RESTART_MSG:
    .asciiz "R- Restart Basic (warm start)"

DISPLAY_MENU:
; Clear screen
    LDA     #$0C            ; FormFeed Clear screen command
    JSR     ECHO
; Display welcome message and menu options
    LDA     #<MEMOART1      ; Load low byte of message address
    LDY     #>MEMOART1      ; Load high byte of message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<MEMOART2      ; Load low byte of message address
    LDY     #>MEMOART2      ; Load high byte of message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<MEMOART3      ; Load low byte of message address
    LDY     #>MEMOART3      ; Load high byte of message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<MEMOART4      ; Load low byte of message address
    LDY     #>MEMOART4      ; Load high byte of message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF

    LDA     #<MENU_WOZMON_MSG  ; Load low byte of WOZMON message address
    LDY     #>MENU_WOZMON_MSG  ; Load high byte of WOZMON message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF

    LDA     #<MENU_BASIC_MSG    ; Load low byte of BASIC message address
    LDY     #>MENU_BASIC_MSG    ; Load high byte of BASIC message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
; Check if external ROM is present and print external ROM message if present
CHECK_ROM:
    LDA     $A000           ; Check for first byte of ROM
    CMP     #$A0            ; Is it $A000 ?
    BEQ     @no_rom         ; No, skip external ROM option.
    ; ROM is present, show the external ROM menu option
    LDA     #<MENU_EXTERNAL_ROM_MSG  ; Load low byte of external ROM message address
    LDY     #>MENU_EXTERNAL_ROM_MSG  ; Load high byte of external ROM message address
    JSR     PRINT_STRING
    LDA     $BFF8       ; Read the name of the external ROM from its header
    CMP     #$FF        ; Check if it's $FF (no name)
    BEQ     @no_rom_name
    CMP     #$00        ; Check if it's $00 (no name)
    BEQ     @no_rom_name
    LDA     $BFF8
    JSR     ECHO
    LDA     $BFF9
    JSR     ECHO
    LDA     $BFFA
    JSR     ECHO
    LDA     $BFFB
    JSR     ECHO
    LDA     $BFFC
    JSR     ECHO
    LDA     $BFFD
    JSR     ECHO
    LDA     $BFFE
    JSR     ECHO
    LDA     $BFFF
    JSR     ECHO
    JSR     PRINT_CR_LF
    JMP     @print_about_menu
@no_rom_name:           ; Print the name of the external ROM
    LDA     #<MENU_EXTERNAL_ROM_NAME_MSG ; Load low byte of "External Slot" message address
    LDY     #>MENU_EXTERNAL_ROM_NAME_MSG ; Load high byte of "External Slot" message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@no_rom:
@print_about_menu:
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<MENU_ABOUT_MSG   ; Load low byte of ABOUT message address
    LDY     #>MENU_ABOUT_MSG   ; Load high byte of ABOUT message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@print_restart_menu:
    LDA     #<MENU_RESTART_MSG   ; Load low byte of RESTART message address
    LDY     #>MENU_RESTART_MSG   ; Load high byte of RESTART message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    RTS

;-----------------------------------------------------
; Print zero-terminated string
; Lower byte of address is in A and higher byte in Y
; Exemple usage:
;   LDA #<string_address
;   LDX #>string_address
;-----------------------------------------------------
PRINT_STRING:
    STA     string_ptr      ; Store low byte of address in zero page
    STY     string_ptr+1    ; Store high byte of address
    LDY     #0              ; String index
@print_loop:
    LDA     (string_ptr),y  ; Get character using indirect Y addressing
    BEQ     @print_done     ; If zero, end of string
    JSR     ECHO            ; Send character
    INY                     ; Next character
    JMP     @print_loop     ; Continue
@print_done:
    RTS

PRINT_CR_LF: 
    PHA
    LDA     #CR
    JSR     ECHO
    LDA     #LF
    JSR     ECHO
    PLA
    RTS

PRINT_FF:
    LDA     #$0C
    JSR     ECHO
    RTS

INIT_VIA:
    LDA     #%10000000      ; Set all bits of port B as input (except PB7 for sound)
    STA     VIA_DDRB        ; Set VIA data direction register B
    LDA     #%00000000      ; Set all bits of port A as input
    STA     VIA_DDRA        ; Set VIA data direction register A
    RTS

INIT_SERIAL_1200:
    LDA     #ACIA_CTRL_1S7B_1200
    STA     ACIA_CTRL
    LDA     #ACIA_CMD_PEN_EOFF
    STA     ACIA_CMD
    RTS

INIT_SERIAL_4800:
    LDA     #ACIA_CTRL_1S7B_4800
    STA     ACIA_CTRL
    LDA     #ACIA_CMD_PEN_EOFF
    STA     ACIA_CMD
    RTS

SMALL_DELAY:    
; just a dumb loop for now
    ldx #$80
@loop1:
    ldy #$FF
@loop2:
    dey
    bne @loop2
    dex
    bne @loop1
    rts

WELCOME_TONE:
    JSR     PLAY_TONE_DO4
    JSR     SMALL_DELAY
    JSR     PLAY_TONE_MI4
    JSR     SMALL_DELAY
    JSR     PLAY_TONE_FA4
    JSR     SMALL_DELAY
    JSR     STOP_TONE
    RTS

RESET:
    CLD                     ; Clear decimal arithmetic mode.
    JSR     INIT_BUFFER     ; Initialize input buffer.
    CLI
    JSR     INIT_SERIAL_1200 ; Initialize serial for 1200 baud.
    JSR     DISABLE_ECHO
    JSR     SEND_4800_COMMAND ; Send 4800 baud command to Minitel
    LDA     #ACIA_CTRL_1S7B_4800
    STA     ACIA_CTRL
    JSR     INIT_VIA        ; Initialize VIA for joystick input
WARM_RST:
    JSR     STANDARD_KEYBOARD_MODE ; Set Minitel to standard keyboard mode
    JSR     CURSOR_OFF      ; Turn off cursor
    JSR     PAGE_MODE       ; Set page mode
    JSR     CLEAR_BUFFER
    JSR     DISPLAY_MENU    ; Display menu
    JSR     WELCOME_TONE    ; Play welcome tone
    ; Fall through to WAIT_FOR_KEY
    
WAIT_FOR_KEY:
    JSR     MONRDKEY        ; Get character from buffer
    BCC     WAIT_FOR_KEY    ; No character, try again.
    CMP     #'1'            ; '1' for WOZMON?
    BEQ     GOTO_WOZMON     ; Yes, jump to WOZMON.
    CMP     #'2'            ; '2' for BASIC?
    BEQ     GOTO_BASIC      ; Yes, jump to BASIC.
    CMP     #'3'            ; '3' for external ROM?
    BEQ     GOTO_EXTERNAL_ROM; Yes, go to external ROM location.
    CMP     #'A'            ; 'A' for ABOUT?
    BEQ     GOTO_ABOUT      ; Yes, go to ABOUT location.
    CMP     #'a'            ; 'a' for ABOUT?
    BEQ     GOTO_ABOUT      ; Yes, go to ABOUT location.
    CMP     #'R'            ; 'R' for Restart?
    BEQ     RESTART_BASIC   ; Yes, go to RESTART location.
    CMP     #'r'            ; 'r' for Restart?
    BEQ     RESTART_BASIC   ; Yes, go to RESTART location.
    JMP     WAIT_FOR_KEY    ; Invalid key, wait again.

GOTO_WOZMON:
    JSR     SMALL_BEEP
    JSR     UPPERCASE_MODE
    JSR     SCROLL_MODE
    JSR     CURSOR_HOME
    JSR     CLEAR_SCREEN
    JSR     CURSOR_ON      ; Turn ON cursor
    JSR     CLEAR_BUFFER
    JMP     START_WOZMON
GOTO_BASIC:
    JSR     SMALL_BEEP
    JSR     EXTENDED_KEYBOARD_MODE ; Set Minitel to extended keyboard mode
    JSR     LOWERCASE_MODE
    JSR     SCROLL_MODE
    JSR     CURSOR_HOME
    JSR     CLEAR_SCREEN
    JSR     CURSOR_ON      ; Turn ON cursor
    JSR     CLEAR_BUFFER
    JMP     COLD_START
GOTO_ABOUT:
    JSR     SMALL_BEEP
    JSR     CURSOR_HOME
    JSR     CLEAR_SCREEN
    JSR     CLEAR_BUFFER
    JMP     DISPLAY_ABOUT
GOTO_EXTERNAL_ROM:
    JSR     SMALL_BEEP
    LDA     $A000           ; Check for first byte of ROM
    CMP     #$A0            ; Is it $A000 ?
    BEQ     WAIT_FOR_KEY    ; No, skip input and wait for key.
    JSR     CURSOR_HOME
    JSR     CLEAR_SCREEN
    JSR     CLEAR_BUFFER
    JMP     $A000
RESTART_BASIC:
    JSR     SMALL_BEEP
    JSR     EXTENDED_KEYBOARD_MODE ; Set Minitel to extended keyboard mode
    JSR     LOWERCASE_MODE
    JSR     SCROLL_MODE
    JSR     CURSOR_HOME
    JSR     CLEAR_SCREEN
    JSR     CURSOR_ON      ; Turn ON cursor
    JSR     CLEAR_BUFFER
    JMP     RESTART

SMALL_BEEP:
    JSR     PLAY_TONE_FA3
    JSR     SMALL_DELAY
    JSR     STOP_TONE
    RTS

;-----------------------------------------------------
; About Section
;-----------------------------------------------------

DISPLAY_ABOUT:
    ; loop through and print each line of the about message
    LDA     #<ABOUT_MSG1    ; Load low byte of about message address
    LDY     #>ABOUT_MSG1    ; Load high byte of about message address
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG2    
    LDY     #>ABOUT_MSG2    
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG3    
    LDY     #>ABOUT_MSG3    
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG4    
    LDY     #>ABOUT_MSG4    
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG5    
    LDY     #>ABOUT_MSG5    
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG11   
    LDY     #>ABOUT_MSG11   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG12   
    LDY     #>ABOUT_MSG12   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG13   
    LDY     #>ABOUT_MSG13   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG14   
    LDY     #>ABOUT_MSG14   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG15   
    LDY     #>ABOUT_MSG15   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG16   
    LDY     #>ABOUT_MSG16   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<ABOUT_MSG17   
    LDY     #>ABOUT_MSG17   
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF

@about_done:
    JSR     MONRDKEY        ; Get character from buffer
    BCC     @about_done     ; No character, try again.
    JMP     WARM_RST        ; Return to menu

ABOUT_MSG1:
    .asciiz "      Memo-1"
ABOUT_MSG2:
    .asciiz "A 65C02 chip set based computer, for funand for learning purposes."
ABOUT_MSG3:
    .asciiz "by Benoit Aveline - aka Memoire Morte"
ABOUT_MSG4:
    .asciiz "(c) 2025 - Creative Commons BY-NC-SA"
ABOUT_MSG5:
    .asciiz "Full source and derived licenses at:    https://github.com/MemoireMorte/Memo-1"
ABOUT_MSG11:
    .asciiz "Special thanks to:"
ABOUT_MSG12:
    .asciiz " - B. Eater for his 6502 computer design and tutorials"
ABOUT_MSG13:
    .asciiz " - I. Ward for his YouTube channel on    2004 lcd and 555 timer"
ABOUT_MSG14:
    .asciiz "Current source code is based on:"
ABOUT_MSG15:
    .asciiz " - Wozmon by Steve Wozniak - Apple"
ABOUT_MSG16:
    .asciiz " - BASIC by Weiland & Gates - Microsoft"
ABOUT_MSG17:
    .asciiz " - BASIC disassembly by Michael Steil"
