.setcpu "65C02"

.segment "MENU"

RW_TITLE_MSG:
    .asciiz "Binary Save / Load"
RW_SAVE_MSG:
    .asciiz "S - Save binary to tape"
RW_LOAD_MSG:
    .asciiz "L - Load binary from tape"
RW_BACK_MSG:
    .asciiz "B - Back"
RW_PROMPT_START:
    .asciiz "Start: $"
RW_PROMPT_END:
    .asciiz "End:   $"
RW_MSG_SAVING:
    .asciiz "Saving..."
RW_MSG_SAVE_OK:
    .asciiz "Saved. Press any key."
RW_MSG_LOADING:
    .asciiz "Loading..."
RW_MSG_PRESS_REC:
    .asciiz "Press REC then any key"
RW_MSG_PRESS_PLAY:
    .asciiz "Press PLAY then any key"
RW_MSG_LOAD_OK:
    .asciiz "Loaded."
RW_MSG_DEFAULT:
    .asciiz "Default: $"
RW_MSG_RUN_OPTS:
    .asciiz "R - Run  B - Back"
RW_MSG_ENTRY:
    .asciiz "Entry: $"
RW_MSG_LOAD_ERR:
    .asciiz "Error. Press any key."

;-----------------------------------------------------
; Binary save/load sub-menu
;-----------------------------------------------------
RW_SUBMENU:
    LDA     #$0C
    JSR     ECHO
    LDA     #<RW_TITLE_MSG
    LDY     #>RW_TITLE_MSG
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<RW_SAVE_MSG
    LDY     #>RW_SAVE_MSG
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<RW_LOAD_MSG
    LDY     #>RW_LOAD_MSG
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<RW_BACK_MSG
    LDY     #>RW_BACK_MSG
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF

RW_WAIT_KEY:
    JSR     MONRDKEY
    BCC     RW_WAIT_KEY
    CMP     #'S'
    BEQ     RW_DO_SAVE
    CMP     #'s'
    BEQ     RW_DO_SAVE
    CMP     #'L'
    BEQ     RW_DO_LOAD
    CMP     #'l'
    BEQ     RW_DO_LOAD
    CMP     #'B'
    BEQ     RW_DO_BACK
    CMP     #'b'
    BEQ     RW_DO_BACK
    JMP     RW_WAIT_KEY

RW_DO_BACK:
    JSR     SMALL_BEEP
    JMP     WARM_RST

; =============================================================
; SAVE
; =============================================================
RW_DO_SAVE:
    JSR     SMALL_BEEP
    JSR     CLEAR_BUFFER
    JSR     CURSOR_ON
    LDA     #<RW_PROMPT_START
    LDY     #>RW_PROMPT_START
    JSR     PRINT_STRING
    JSR     RW_INPUT_HEX_START      ; result → KCS_START_LO/HI
    JSR     PRINT_CR_LF
    LDA     #<RW_PROMPT_END
    LDY     #>RW_PROMPT_END
    JSR     PRINT_STRING
    JSR     RW_INPUT_HEX_END        ; result → KCS_LEN_LO/HI (end address, temporarily)
    JSR     PRINT_CR_LF
    ; Compute length = end_addr - start_addr + 1
    SEC
    LDA     KCS_LEN_LO
    SBC     KCS_START_LO
    STA     KCS_LEN_LO
    LDA     KCS_LEN_HI
    SBC     KCS_START_HI
    STA     KCS_LEN_HI
    INC     KCS_LEN_LO
    BNE     @save_go
    INC     KCS_LEN_HI
@save_go:
    LDA     #<RW_MSG_PRESS_REC
    LDY     #>RW_MSG_PRESS_REC
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@save_rec_wait:
    JSR     MONRDKEY
    BCC     @save_rec_wait
    JSR     CLEAR_BUFFER
    LDA     #<RW_MSG_SAVING
    LDY     #>RW_MSG_SAVING
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     KCS_SAVE
    LDA     #<RW_MSG_SAVE_OK
    LDY     #>RW_MSG_SAVE_OK
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@save_wait:
    JSR     MONRDKEY
    BCC     @save_wait
    JSR     CURSOR_OFF
    JMP     RW_SUBMENU

; =============================================================
; LOAD
; =============================================================
RW_DO_LOAD:
    JSR     SMALL_BEEP
    JSR     CLEAR_BUFFER
    JSR     CURSOR_ON
    LDA     #<RW_MSG_PRESS_PLAY
    LDY     #>RW_MSG_PRESS_PLAY
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@load_play_wait:
    JSR     MONRDKEY
    BCC     @load_play_wait
    JSR     CLEAR_BUFFER
    LDA     #<RW_MSG_LOADING
    LDY     #>RW_MSG_LOADING
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    JSR     KCS_LOAD                ; RW_JUMP_LO/HI set to original start on success
    BCS     @load_error

    ; Show loaded address and run options
    LDA     #<RW_MSG_LOAD_OK        ; "Loaded."
    LDY     #>RW_MSG_LOAD_OK
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
    LDA     #<RW_MSG_DEFAULT        ; "Default: $"
    LDY     #>RW_MSG_DEFAULT
    JSR     PRINT_STRING
    LDA     RW_JUMP_HI
    JSR     RW_PRINT_BYTE_HEX
    LDA     RW_JUMP_LO
    JSR     RW_PRINT_BYTE_HEX
    JSR     PRINT_CR_LF
    JSR     PRINT_CR_LF
    LDA     #<RW_MSG_RUN_OPTS       ; "R - Run  B - Back"
    LDY     #>RW_MSG_RUN_OPTS
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF

@run_ask:
    JSR     MONRDKEY
    BCC     @run_ask
    CMP     #'R'
    BEQ     @do_run
    CMP     #'r'
    BEQ     @do_run
    CMP     #'B'
    BEQ     @back
    CMP     #'b'
    BEQ     @back
    BRA     @run_ask

@do_run:
    ; Back up the default so RW_INPUT_HEX_JUMP can restore it on full backspace
    LDA     RW_JUMP_LO
    STA     RW_DEFAULT_LO
    LDA     RW_JUMP_HI
    STA     RW_DEFAULT_HI
    ; Prompt for entry address (Enter alone uses the default)
    LDA     #<RW_MSG_ENTRY          ; "Entry: $"
    LDY     #>RW_MSG_ENTRY
    JSR     PRINT_STRING
    JSR     RW_INPUT_HEX_JUMP       ; result in RW_JUMP_LO/HI
    JSR     PRINT_CR_LF
    JMP     (RW_JUMP_LO)            ; absolute indirect jump to entry point

@back:
    JSR     CURSOR_OFF
    JMP     RW_SUBMENU

@load_error:
    LDA     #<RW_MSG_LOAD_ERR
    LDY     #>RW_MSG_LOAD_ERR
    JSR     PRINT_STRING
    JSR     PRINT_CR_LF
@err_wait:
    JSR     MONRDKEY
    BCC     @err_wait
    JSR     CURSOR_OFF
    JMP     RW_SUBMENU

; =============================================================
; RW_NIBBLE_TO_HEX
; Convert a 4-bit nibble to its ASCII hex character.
; Relies on the carry flag set by the preceding CMP #10:
;   C=0 (A < 10)  → digit    '0'–'9'
;   C=1 (A >= 10) → letter   'A'–'F'
; Input:  A = nibble (0–15), carry set by CMP #10 just before call
; Output: A = ASCII character
; Modifies: A
; =============================================================
RW_NIBBLE_TO_HEX:
    AND     #$0F
    CMP     #10
    BCC     @digit
    ADC     #'A'-11         ; C=1 from CMP: A + 1 + ('A'-11) = A + 'A' - 10
    RTS
@digit:
    ADC     #'0'            ; C=0 from BCC: A + 0 + '0'
    RTS

; =============================================================
; RW_PRINT_BYTE_HEX
; Print one byte as two uppercase hex characters.
; Input:  A = byte to print
; Output: none
; Modifies: A
; =============================================================
RW_PRINT_BYTE_HEX:
    PHA
    LSR     A
    LSR     A
    LSR     A
    LSR     A               ; high nibble in bits 3–0
    JSR     RW_NIBBLE_TO_HEX
    JSR     ECHO
    PLA
    AND     #$0F            ; low nibble
    JSR     RW_NIBBLE_TO_HEX
    JSR     ECHO
    RTS

; =============================================================
; RW_HEX_NIBBLE
; Convert an ASCII hex character to its 4-bit value.
; Input:  A = ASCII character ('0'–'9', 'A'–'F', 'a'–'f')
; Output: A = nibble (0–15), C=0 on success
;         C=1 if not a valid hex character
; Modifies: A
; =============================================================
RW_HEX_NIBBLE:
    CMP     #'0'
    BCC     @invalid
    CMP     #'9'+1
    BCC     @is_digit
    CMP     #'A'
    BCC     @invalid
    CMP     #'F'+1
    BCC     @is_upper
    CMP     #'a'
    BCC     @invalid
    CMP     #'f'+1
    BCC     @is_lower
@invalid:
    SEC
    RTS
@is_digit:
    SEC
    SBC     #'0'
    CLC
    RTS
@is_upper:
    SEC
    SBC     #'A'-10
    CLC
    RTS
@is_lower:
    SEC
    SBC     #'a'-10
    CLC
    RTS

; =============================================================
; RW_INPUT_HEX_START
; Read up to 4 hex digits and store the result in
; KCS_START_LO / KCS_START_HI.
;
; Uses BUFFER_SIZE + READ_BUFFER directly (no auto-echo) for
; full control: invalid chars are silently dropped, backspace
; visually erases the last accepted digit, CR ends input.
;
; Input:  none
; Output: KCS_START_LO, KCS_START_HI set to entered address
; Modifies: A, X, Y
; =============================================================
RW_INPUT_HEX_START:
    STZ     KCS_START_LO
    STZ     KCS_START_HI
    LDX     #0                      ; digit count
@wait:
    JSR     BUFFER_SIZE
    BEQ     @wait
    PHX                             ; READ_BUFFER clobbers X
    JSR     READ_BUFFER
    PLX
    CMP     #CR
    BEQ     @done
    CMP     #$08
    BEQ     @backspace
    CMP     #$7F
    BEQ     @backspace
    CPX     #4
    BEQ     @wait
    PHA
    JSR     RW_HEX_NIBBLE
    BCS     @invalid
    TAY                             ; Y = nibble
    PLA                             ; A = original char
    JSR     ECHO
    ASL     KCS_START_LO
    ROL     KCS_START_HI
    ASL     KCS_START_LO
    ROL     KCS_START_HI
    ASL     KCS_START_LO
    ROL     KCS_START_HI
    ASL     KCS_START_LO
    ROL     KCS_START_HI
    TYA
    ORA     KCS_START_LO
    STA     KCS_START_LO
    INX
    BRA     @wait
@invalid:
    PLA
    BRA     @wait
@backspace:
    CPX     #0
    BEQ     @wait
    LSR     KCS_START_HI
    ROR     KCS_START_LO
    LSR     KCS_START_HI
    ROR     KCS_START_LO
    LSR     KCS_START_HI
    ROR     KCS_START_LO
    LSR     KCS_START_HI
    ROR     KCS_START_LO
    DEX
    LDA     #$08
    JSR     ECHO
    LDA     #' '
    JSR     ECHO
    LDA     #$08
    JSR     ECHO
    BRA     @wait
@done:
    RTS

; =============================================================
; RW_INPUT_HEX_END  (same logic, targets KCS_LEN_LO/HI)
; =============================================================
RW_INPUT_HEX_END:
    STZ     KCS_LEN_LO
    STZ     KCS_LEN_HI
    LDX     #0
@wait:
    JSR     BUFFER_SIZE
    BEQ     @wait
    PHX
    JSR     READ_BUFFER
    PLX
    CMP     #CR
    BEQ     @done
    CMP     #$08
    BEQ     @backspace
    CMP     #$7F
    BEQ     @backspace
    CPX     #4
    BEQ     @wait
    PHA
    JSR     RW_HEX_NIBBLE
    BCS     @invalid
    TAY
    PLA
    JSR     ECHO
    ASL     KCS_LEN_LO
    ROL     KCS_LEN_HI
    ASL     KCS_LEN_LO
    ROL     KCS_LEN_HI
    ASL     KCS_LEN_LO
    ROL     KCS_LEN_HI
    ASL     KCS_LEN_LO
    ROL     KCS_LEN_HI
    TYA
    ORA     KCS_LEN_LO
    STA     KCS_LEN_LO
    INX
    BRA     @wait
@invalid:
    PLA
    BRA     @wait
@backspace:
    CPX     #0
    BEQ     @wait
    LSR     KCS_LEN_HI
    ROR     KCS_LEN_LO
    LSR     KCS_LEN_HI
    ROR     KCS_LEN_LO
    LSR     KCS_LEN_HI
    ROR     KCS_LEN_LO
    LSR     KCS_LEN_HI
    ROR     KCS_LEN_LO
    DEX
    LDA     #$08
    JSR     ECHO
    LDA     #' '
    JSR     ECHO
    LDA     #$08
    JSR     ECHO
    BRA     @wait
@done:
    RTS

; =============================================================
; RW_INPUT_HEX_JUMP
; Read up to 4 hex digits for the entry address, storing the
; result directly in RW_JUMP_LO / RW_JUMP_HI ($0200-$0201).
;
; Before calling, RW_JUMP_LO/HI must already hold the default
; address (written by KCS_LOAD), and that same value must be
; backed up in RW_DEFAULT_LO/HI by the caller.
;
; Behaviour:
;   - Enter with no digits typed → keeps RW_JUMP unchanged (= default)
;   - First valid digit typed    → clears RW_JUMP and starts fresh
;   - Backspace reducing to 0 digits → restores RW_JUMP from RW_DEFAULT
;
; Input:  RW_JUMP_LO/HI = default address (pre-filled by caller)
;         RW_DEFAULT_LO/HI = backup of that default (set by caller)
; Output: RW_JUMP_LO/HI = address to jump to
; Modifies: A, X, Y
; =============================================================
RW_INPUT_HEX_JUMP:
    LDX     #0                      ; 0 = default in use; >0 = user is typing
@wait:
    JSR     BUFFER_SIZE
    BEQ     @wait
    PHX
    JSR     READ_BUFFER
    PLX
    CMP     #CR
    BNE     @not_enter
    RTS                             ; Enter: use whatever is in RW_JUMP
@not_enter:
    CMP     #$08
    BEQ     @backspace
    CMP     #$7F
    BEQ     @backspace
    CPX     #4
    BEQ     @wait
    PHA
    JSR     RW_HEX_NIBBLE
    BCS     @invalid
    TAY                             ; Y = nibble
    PLA                             ; A = original char
    CPX     #0                      ; first digit typed?
    BNE     @accumulate
    STZ     RW_JUMP_LO              ; clear default on first digit
    STZ     RW_JUMP_HI
@accumulate:
    JSR     ECHO
    ASL     RW_JUMP_LO
    ROL     RW_JUMP_HI
    ASL     RW_JUMP_LO
    ROL     RW_JUMP_HI
    ASL     RW_JUMP_LO
    ROL     RW_JUMP_HI
    ASL     RW_JUMP_LO
    ROL     RW_JUMP_HI
    TYA
    ORA     RW_JUMP_LO
    STA     RW_JUMP_LO
    INX
    BRA     @wait
@invalid:
    PLA
    BRA     @wait
@backspace:
    CPX     #0
    BEQ     @wait                   ; on default, ignore backspace
    LSR     RW_JUMP_HI
    ROR     RW_JUMP_LO
    LSR     RW_JUMP_HI
    ROR     RW_JUMP_LO
    LSR     RW_JUMP_HI
    ROR     RW_JUMP_LO
    LSR     RW_JUMP_HI
    ROR     RW_JUMP_LO
    DEX
    BNE     @erase_char             ; still have typed digits, just erase
    LDA     RW_DEFAULT_LO           ; back to zero typed digits: restore default
    STA     RW_JUMP_LO
    LDA     RW_DEFAULT_HI
    STA     RW_JUMP_HI
@erase_char:
    LDA     #$08
    JSR     ECHO
    LDA     #' '
    JSR     ECHO
    LDA     #$08
    JSR     ECHO
    JMP     @wait
@done:
    RTS
