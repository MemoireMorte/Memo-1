; KCS - Kansas City Standard
; 1 MHz CPU
;
; *** IMPORTANT: PAGE BOUNDARY WARNING ***
; The delay loops in KCS_HALF_1200 and KCS_HALF_2400 are timing-critical.
; If a BNE @delay instruction crosses a page boundary, the branch takes 4
; cycles instead of 3, silently breaking the output frequency.
; When adding the KCS segment to memo.cfg, either align it to a page
; boundary or verify that both @delay labels and their BNE instructions
; land on the same memory page.

.setcpu "65C02"

; Zero page variables
.zeropage
.org ZP_KCS_START
KCS_OUT_STATE:  .res 1  ; Current D0 output level (0 or 1)
KCS_START_LO:   .res 1  ; Save block start address, low byte
KCS_START_HI:   .res 1  ; Save block start address, high byte
KCS_LEN_LO:     .res 1  ; Save block length, low byte
KCS_LEN_HI:     .res 1  ; Save block length, high byte
KCS_CHECKSUM:   .res 1  ; XOR checksum accumulator

.code

; Tape block magic bytes identifying a Memo-1 KCS block
KCS_MAGIC_0 = $4D   ; 'M'
KCS_MAGIC_1 = $31   ; '1'

KCS_PORT = $B000    ; Bit-banged output register
                    ; $A000-$AFFF left available for an external storage ROM
                    ; D0 is the audio output bit (latched on each write)
                    ; Address decode: /Ext Select + A12 distinguishes $Bxxx from $Axxx
                    ; Minimal hardware: 74LS00 NAND (decode + write strobe) + 74LS74 (D0 latch)


; 300 baud
; | Bit | Frequency | Period  | Cycles             |
; | --- | --------- | ------- | ------------------ |
; | `0` | 1200 Hz   | ~833 µs | 4 cycles at 1200 Hz|
; | `1` | 2400 Hz   | ~416 µs | 8 cycles at 2400 Hz|

; START  D0 D1 D2 D3 D4 D5 D6 D7  STOP STOP
;   0     LSB → MSB                1    1

; Leader (before data):
;
; Long sequence of 1s (2400 Hz)
; Allows:
;   - reader stabilization
;   - synchronization
;
; Minimum 5 seconds as per KCS spec

;-----------------------------------------------------
; Toggle D0 on KCS_PORT to produce the next half-cycle
; Maintains current output state in KCS_OUT_STATE
; Cycle count: 18 body + 6 RTS = 24 total when called via JSR
; KCS_OUT_STATE must be initialised to 0 before first call
; Input:  none
; Output: none
; Modifies: A
;-----------------------------------------------------
KCS_TOGGLE:
    LDA KCS_OUT_STATE   ; 3 - load current output state
    EOR #$01            ; 2 - toggle D0
    STA KCS_OUT_STATE   ; 3 - save new state
    STA KCS_PORT        ; 4 - write D0 to latch
    RTS                 ; 6

;-----------------------------------------------------
; Output one half-period at 1200 Hz (417 cycles total
; including JSR/RTS overhead)
; Calls KCS_TOGGLE then busy-waits for the remainder
; Cycle budget: 6 (JSR) + 24 (toggle) + 381 (delay) + 6 (RTS) = 417
; Delay: LDX #76 (2) + 75x(DEX+BNE taken)(375) + DEX+BNE fall(4) = 381
; Input:  none
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_HALF_1200:
    JSR KCS_TOGGLE      ; 24 - toggle output and drive latch
    LDX #76             ;  2
@delay:
    DEX                 ;  2
    BNE @delay          ;  3 / 2 on exit
    RTS                 ;  6

;-----------------------------------------------------
; Output one half-period at 2400 Hz (208 cycles total
; including JSR/RTS overhead)
; Calls KCS_TOGGLE then busy-waits for the remainder
; Cycle budget: 6 (JSR) + 24 (toggle) + 6 (3xNOP) + 166 (delay) + 6 (RTS) = 208
; Delay: LDX #33 (2) + 32x(DEX+BNE taken)(160) + DEX+BNE fall(4) = 166
; Input:  none
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_HALF_2400:
    JSR KCS_TOGGLE      ; 24 - toggle output and drive latch
    NOP                 ;  2
    NOP                 ;  2
    NOP                 ;  2
    LDX #33             ;  2
@delay:
    DEX                 ;  2
    BNE @delay          ;  3 / 2 on exit
    RTS                 ;  6

;-----------------------------------------------------
; Send a 0 bit: 4 full cycles at 1200 Hz
; = 8 half-periods, unrolled to avoid loop overhead
; between calls that would distort the frequency
; Input:  none
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_SEND_BIT_0:
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    JSR KCS_HALF_1200
    RTS

;-----------------------------------------------------
; Send a 1 bit: 8 full cycles at 2400 Hz
; = 16 half-periods, unrolled to avoid loop overhead
; between calls that would distort the frequency
; Input:  none
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_SEND_BIT_1:
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    JSR KCS_HALF_2400
    RTS

;-----------------------------------------------------
; Send one byte as a KCS frame
; Frame: 1 start bit (0), 8 data bits LSB first, 2 stop bits (1)
; Input:  A = byte to send
; Output: none
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_SEND_BYTE:
    PHA                     ; save byte — A clobbered by subroutines
    JSR KCS_SEND_BIT_0      ; start bit
    PLA                     ; recover byte
    LDY #8                  ; 8 data bits, LSB first
@loop:
    LSR A                   ; shift LSB into carry
    PHA                     ; save shifted byte before subroutine clobbers A
    BCS @one
    JSR KCS_SEND_BIT_0
    BRA @next
@one:
    JSR KCS_SEND_BIT_1
@next:
    PLA                     ; recover shifted byte for next iteration
    DEY
    BNE @loop
    JSR KCS_SEND_BIT_1      ; stop bit 1
    JSR KCS_SEND_BIT_1      ; stop bit 2
    RTS

;-----------------------------------------------------
; Send the KCS leader: 5 seconds of continuous 1 bits
; at 2400 Hz (~1500 bit-times at 300 baud)
; Allows the tape reader to lock onto the signal
; Timing: 1500 bits * ~3340 cycles/bit ≈ 5.017 s @ 1 MHz
; Loop structure: A=6 outer (stack-saved) * Y=250 inner = 1500 iterations
; X is clobbered by KCS_SEND_BIT_1 subroutine chain
; Input:  none
; Output: none
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_SEND_LEADER:
    STZ KCS_OUT_STATE       ; D0 starts low before first toggle
    LDA #6
@outer:
    PHA
    LDY #250
@inner:
    JSR KCS_SEND_BIT_1
    DEY
    BNE @inner
    PLA
    SEC
    SBC #1
    BNE @outer
    RTS

;-----------------------------------------------------
; Save a block of memory to tape
;
; Block format on tape:
;   [leader]          5+ seconds of 2400 Hz tone
;   [magic]           $4D $31 ('M','1') — Memo-1 identifier
;   [start addr]      2 bytes, little-endian
;   [length]          2 bytes, little-endian
;   [data]            <length> bytes
;   [checksum]        1 byte, XOR of data bytes only
;
; KCS_START_LO/HI and KCS_LEN_LO/HI are consumed as a
; walking pointer and down-counter respectively during
; the data loop. They are not preserved on return.
;
; A length of zero is not supported.
;
; Input:  KCS_START_LO / KCS_START_HI = start address
;         KCS_LEN_LO   / KCS_LEN_HI   = byte count (must be > 0)
; Output: none
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_SAVE:

    ; --- Leader ---
    ; KCS_SEND_LEADER also initialises KCS_OUT_STATE to 0
    JSR KCS_SEND_LEADER

    ; --- Header (not checksummed) ---
    ; Magic bytes identify this as a Memo-1 KCS block
    LDA #KCS_MAGIC_0
    JSR KCS_SEND_BYTE
    LDA #KCS_MAGIC_1
    JSR KCS_SEND_BYTE

    ; Start address, little-endian
    LDA KCS_START_LO
    JSR KCS_SEND_BYTE
    LDA KCS_START_HI
    JSR KCS_SEND_BYTE

    ; Byte count, little-endian
    LDA KCS_LEN_LO
    JSR KCS_SEND_BYTE
    LDA KCS_LEN_HI
    JSR KCS_SEND_BYTE

    ; --- Data + checksum accumulation ---
    STZ KCS_CHECKSUM            ; initialise XOR checksum to 0

    ; KCS_START_LO/HI are consecutive ZP bytes ($F5/$F6),
    ; so LDA (KCS_START_LO) is valid zero-page indirect
    ; addressing — no separate pointer variable needed.
@data_loop:
    LDA (KCS_START_LO)          ; load byte at current address
    PHA                         ; preserve it — A is clobbered below
    EOR KCS_CHECKSUM            ; fold byte into running XOR checksum
    STA KCS_CHECKSUM
    PLA                         ; restore original byte for sending
    JSR KCS_SEND_BYTE

    ; Advance the pointer by 1
    INC KCS_START_LO
    BNE @no_carry               ; skip HI increment if no page crossing
    INC KCS_START_HI
@no_carry:

    ; Decrement 16-bit length counter.
    ; Check LO first: if it is non-zero, decrement it directly
    ; (no borrow into HI). If it is zero, borrow: decrement HI
    ; first, then let DEC wrap LO from $00 to $FF.
    LDA KCS_LEN_LO
    BNE @no_borrow
    DEC KCS_LEN_HI
@no_borrow:
    DEC KCS_LEN_LO

    ; Loop until both bytes of the counter reach zero
    LDA KCS_LEN_LO
    ORA KCS_LEN_HI
    BNE @data_loop

    ; --- Checksum byte ---
    ; XOR of all data bytes, sent as the final byte of the block
    LDA KCS_CHECKSUM
    JSR KCS_SEND_BYTE

    ; --- Cleanup ---
    ; Drive D0 low so the output latch does not hold a stale
    ; high level after the save completes
    STZ KCS_OUT_STATE
    STZ KCS_PORT

    RTS