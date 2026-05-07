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

; Zero page variables are defined as equates in defines_memo.s
; (KCS_OUT_STATE, KCS_START_LO/HI, KCS_LEN_LO/HI, KCS_CHECKSUM)

.segment "KCS"

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

; ============================================================
; KCS LOAD ROUTINES
; ============================================================

; Read port: tri-state buffer driven by audio comparator/Schmitt trigger
; Address TBD — update once the input circuit is finalised
; Hardware requirement: reading KCS_PORT_IN must place the current
; audio bit on D0 of the data bus.
KCS_PORT_IN       = $B001

; Half-period classification threshold (iterations, not cycles)
; Loop body: 16 cycles/iteration @ 1 MHz
;   1200 Hz half-period (~417 cycles) → ~26 iterations
;   2400 Hz half-period (~208 cycles) → ~13 iterations
;   Threshold midpoint: 19  (valid for ±10% cassette speed)
KCS_HALF_THRESHOLD = 19

; KCS_OUT_STATE ($F4) is unused during LOAD (output is idle).
; KCS_SKIP_ONE_EDGE and KCS_MEASURE_HALF both use it as a
; scratch register to hold the sampled input level.

;-----------------------------------------------------
; Wait for input level to change (consume one half-period)
; Uses KCS_OUT_STATE to hold the initial level for comparison
; Input:  none
; Output: none
; Modifies: A
;-----------------------------------------------------
KCS_SKIP_ONE_EDGE:
    LDA KCS_PORT_IN      ; 4 - sample current level
    AND #$01             ; 2
    STA KCS_OUT_STATE    ; 3 - save reference level
@wait:
    LDA KCS_PORT_IN      ; 4
    AND #$01             ; 2
    CMP KCS_OUT_STATE    ; 3
    BEQ @wait            ; 3/2 - still same level, keep polling
    ; Level changed — confirm with two more samples to reject glitches
    LDA KCS_PORT_IN      ; 4 - sample 2
    AND #$01             ; 2
    CMP KCS_OUT_STATE    ; 3 - still different from original?
    BEQ @wait            ; 3 - bounced back: false glitch, keep waiting
    LDA KCS_PORT_IN      ; 4 - sample 3
    AND #$01             ; 2
    CMP KCS_OUT_STATE    ; 3 - still different?
    BEQ @wait            ; 3 - bounced back: false glitch, keep waiting
    ; Three consecutive samples on the new side — real transition confirmed
    RTS

;-----------------------------------------------------
; Wait for A half-period boundaries (A transitions)
; Input:  A = number of edges to consume (must be > 0)
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_SKIP_EDGES:
    TAX                  ; X = edge count
@loop:
    JSR KCS_SKIP_ONE_EDGE
    DEX
    BNE @loop
    RTS

;-----------------------------------------------------
; Measure the current half-period duration
; Samples input state, counts iterations until it changes
; Loop body: 16 cycles/iter (INX + BEQ + LDA abs + AND + CMP zp + BEQ)
; Returns: C=1 → short (< KCS_HALF_THRESHOLD iter) = 2400 Hz = 1-bit
;          C=0 → long (≥ KCS_HALF_THRESHOLD iter) = 1200 Hz = 0-bit
;                or timeout (X wrapped to 0, ~4 ms with no edge)
; Modifies: A, X
;-----------------------------------------------------
KCS_MEASURE_HALF:
    LDA KCS_PORT_IN      ; 4
    AND #$01             ; 2
    STA KCS_OUT_STATE    ; 3 - save initial state
    LDX #$00             ; 2
@loop:
    INX                  ; 2
    BEQ @timeout         ; 3/2 - X wrapped: no edge in 255 iterations
    LDA KCS_PORT_IN      ; 4
    AND #$01             ; 2
    CMP KCS_OUT_STATE    ; 3
    BEQ @loop            ; 3/2 - still same level
    ; Level changed: reject noise glitches shorter than 5 iterations (~75 µs)
    ; Real 2400 Hz half-periods measure ~12 iterations, so 5 is a safe floor.
    CPX #5
    BCS @real_edge
    ; Glitch: adopt the new level as reference and keep counting
    STA KCS_OUT_STATE     ; A = new level (from AND #$01 above)
    BRA @loop
@real_edge:
.ifdef KCS_DEBUG
    STX KCS_LAST_X            ; DEBUG: save raw iteration count for caller to log
.endif
    CPX #KCS_HALF_THRESHOLD   ; C set if X >= threshold (long = 0-bit)
    BCS @long
    SEC                  ; X < threshold: short = 1-bit
    RTS
@long:
    CLC                  ; X >= threshold: long = 0-bit
    RTS
@timeout:
    ; X wrapped to 0: no edge seen in ~4 ms (signal absent or DC stuck)
    ; CLC makes this indistinguishable from a genuine long half-period.
    ; In KCS_WAIT_LEADER this is harmless (BCC @reset keeps looping).
    ; In @find_start it will cause a false exit, after which KCS_SKIP_ONE_EDGE
    ; hangs waiting for an edge that never arrives — machine must be reset.
    CLC
    RTS

;-----------------------------------------------------
; Wait for 200 consecutive short half-periods (2400 Hz leader)
; Resets counter on any long half-period
; Ensures signal is stable before attempting to read data
; 200 × 208 µs ≈ 42 ms of clean 2400 Hz required
; Input:  none
; Output: none
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_WAIT_LEADER:
    LDY #200
@loop:
    JSR KCS_MEASURE_HALF ; C=1: short; C=0: long or timeout
    BCC @reset           ; long half-period → not pure 2400 Hz, restart count
    DEY
    BNE @loop
    RTS                  ; 200 consecutive short half-periods confirmed
@reset:
    LDY #200
    BRA @loop

;-----------------------------------------------------
; Read one complete KCS bit — transition counting (Acorn Atom method)
; Counts all signal transitions during exactly one bit period (~3333 cycles at 1 MHz).
; 0-bit (1200 Hz): ~8 transitions   1-bit (2400 Hz): ~16 transitions
; Threshold 12 is the exact midpoint → ±4 transition noise tolerance.
;
; Must be called at a data bit boundary (immediately after start bit
; or previous data bit). Does NOT call KCS_SKIP_EDGES.
;
; KCS_LAST_X is repurposed here as the loop countdown register:
;   production: holds countdown value (165 → 0)
;   debug:      holds countdown, then overwritten with transition count for logging
;
; Loop timing: 20 cycles/iter (no transition) × 165 = 3300 cycles.
; Plus ~33 cycles of setup/exit overhead ≈ 3333 cycles total. Tune #165 if needed.
;
; Input:  none
; Output: C=1 → 1-bit; C=0 → 0-bit  (C set directly by CPX #12)
; Modifies: A, X  (Y preserved)
;-----------------------------------------------------
KCS_READ_BIT:
    LDA KCS_PORT_IN       ; 4  snapshot current signal level
    AND #$01              ; 2
    STA KCS_OUT_STATE     ; 3  reference level for transition detection
    LDX #0                ; 2  clear transition counter
    LDA #165              ; 2  countdown: 165 × ~20 cycles ≈ 3300 cycles
    STA KCS_LAST_X        ; 3  store countdown (KCS_LAST_X repurposed)
@count_loop:
    LDA KCS_PORT_IN       ; 4  sample input
    AND #$01              ; 2
    CMP KCS_OUT_STATE     ; 3  transition?
    BEQ @no_change        ; 3/2
    STA KCS_OUT_STATE     ; 3  update reference to new level
    INX                   ; 2  count this transition
@no_change:
    DEC KCS_LAST_X        ; 5  decrement countdown
    BNE @count_loop       ; 3/2
    ; X = total transitions in one bit period
    ; ~8 → 0-bit (C=0 after CPX); ~16 → 1-bit (C=1 after CPX)
.ifdef KCS_DEBUG
    STX KCS_LAST_X        ; save count before clobbering X
    LDX KCS_LOG_IDX
    LDA KCS_LAST_X        ; A = transition count
    STA KCS_LOG_BUF, X
    INC KCS_LOG_IDX
    LDX KCS_LAST_X        ; restore X = count for CPX
.endif
    CPX #12               ; C=1 if X >= 12 → 1-bit; C=0 if X < 12 → 0-bit
    RTS                   ; return with C set by CPX (no SEC/CLC needed)

;-----------------------------------------------------
; Read one KCS byte
; Scans for start bit (8 consecutive long half-periods), collects 8 data
; bits LSB first using ROR accumulation.
;
; Start bit detection (Acorn Atom method):
;   Accumulate 8 consecutive long half-periods using Y as a counter
;   (Y init=$78; 8 INY ops reach $80, setting bit 7 → BPL fails → exit).
;   Reset on ANY short half-period → requires 3.33 ms of sustained 1200 Hz
;   to confirm. Consumes the full start bit with no separate drain step.
;
; ROR accumulation: each received bit (in carry) shifted into bit 7.
;   After 8 RORs of $00, first-received bit is at position 0. ✓
;
; Input:  none
; Output: A = received byte
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_READ_BYTE:
    ; Hunt for start bit: find 2 consecutive long half-periods, drain 6 more.
    ; Total: 8 half-periods consumed = one full start bit (1200 Hz).
@find_start:
    JSR KCS_MEASURE_HALF  ; C=0: long (1200 Hz); C=1: short (2400 Hz)
    BCS @find_start       ; short → not a start bit, keep looking
    JSR KCS_MEASURE_HALF  ; confirm: second consecutive long
    BCS @find_start       ; short → first was a fluke, restart
    LDA #6
    JSR KCS_SKIP_EDGES    ; drain remaining 6 half-periods of the start bit
    ; 2 measured + 6 drained = 8 half-periods consumed = now at data bit 0 boundary
    LDA #$00
    PHA                   ; push zero as initial byte accumulator
    LDY #8                ; bit counter
@bit_loop:
    JSR KCS_READ_BIT      ; C = received bit (clobbers A, X; Y preserved)
    PLA
    ROR A                 ; shift carry (received bit) into bit 7
    PHA
    DEY
    BNE @bit_loop
    PLA                   ; retrieve assembled byte
    CLC                   ; no error
    RTS

;-----------------------------------------------------
; Load a block from tape into memory
;
; Block format (matches KCS_SAVE):
;   [leader]      128+ short half-periods (2400 Hz)
;   [magic]       $4D $31 ('M','1') — Memo-1 identifier
;   [start_lo]    destination address, low byte
;   [start_hi]    destination address, high byte
;   [len_lo]      byte count, low byte
;   [len_hi]      byte count, high byte
;   [data]        <len> bytes
;   [checksum]    XOR of data bytes only
;
; After a successful load:
;   KCS_START_LO/HI = original_start + len = new VARTAB
;   KCS_LEN_LO/HI   = 0
;   KCS_CHECKSUM     = computed XOR (should match tape checksum)
;
; Input:  none
; Output: C=0 success; C=1 error (bad magic or checksum mismatch)
; Modifies: A, X, Y
;-----------------------------------------------------
KCS_LOAD:
    ; --- Init bit log ---
    STZ KCS_LOG_IDX               ; DEBUG: reset log index
    LDA #'W'                      ; DEBUG: waiting for leader
    JSR CHROUT

    ; --- Wait for leader ---
    JSR KCS_WAIT_LEADER

    ; --- Read and verify magic bytes ---
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    PLA
.endif
    CMP #KCS_MAGIC_0              ; 'M'
    BNE @bad_magic
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    PLA
.endif
    CMP #KCS_MAGIC_1              ; '1'
    BNE @bad_magic
    BRA @magic_ok
@bad_magic:
    JMP @error
@magic_ok:

    ; --- Read destination address (little-endian) ---
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    PLA
.endif
    STA KCS_START_LO
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    PLA
.endif
    STA KCS_START_HI
    ; Snapshot original start for the run prompt in read_write.s
    ; (KCS_START_LO/HI walk forward during the data loop and are not preserved)
    STA RW_JUMP_HI                ; A still holds the hi byte
    LDA KCS_START_LO
    STA RW_JUMP_LO

    ; --- Read byte count (little-endian) ---
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    PLA
.endif
    STA KCS_LEN_LO
    JSR KCS_READ_BYTE
.ifdef KCS_DEBUG
    PHA
    JSR KCS_PRINT_HEX          ; print len_hi
    LDA #$0D
    JSR CHROUT
    LDA #$0A
    JSR CHROUT
    JSR KCS_DUMP_LOG            ; dump all transition counts for the 6 header bytes
    PLA
.endif
    STA KCS_LEN_HI

    ; --- Read data bytes, store, and accumulate XOR checksum ---
    STZ KCS_CHECKSUM
@data_loop:
    JSR KCS_READ_BYTE
    STA (KCS_START_LO)          ; write to current destination
    EOR KCS_CHECKSUM
    STA KCS_CHECKSUM
    ; Advance 16-bit pointer
    INC KCS_START_LO
    BNE @no_carry
    INC KCS_START_HI
@no_carry:
    ; Decrement 16-bit counter (borrow: DEC HI before LO wraps $00→$FF)
    LDA KCS_LEN_LO
    BNE @no_borrow
    DEC KCS_LEN_HI
@no_borrow:
    DEC KCS_LEN_LO
    LDA KCS_LEN_LO
    ORA KCS_LEN_HI
    BNE @data_loop

    ; --- Read and verify checksum ---
    JSR KCS_READ_BYTE            ; A = checksum byte from tape
    CMP KCS_CHECKSUM             ; compare to computed XOR
    BEQ @cksum_ok
    ; Mismatch: print "Xrr cc" (rr=received, cc=computed) then error
    PHA                          ; save received byte
    LDA #'X'
    JSR CHROUT
    PLA                          ; A = received byte from tape
    JSR KCS_PRINT_HEX
    LDA #' '
    JSR CHROUT
    LDA KCS_CHECKSUM             ; A = locally computed XOR
    JSR KCS_PRINT_HEX
    LDA #$0D
    JSR CHROUT
    LDA #$0A
    JSR CHROUT
    BRA @error
@cksum_ok:
    CLC                          ; success
    RTS

@error:
    ; DEBUG: dump bit log over serial then signal error
    JSR KCS_DUMP_LOG
    SEC                          ; error
    RTS

;-----------------------------------------------------
; Dump the bit log to serial (debug only)
; Prints all bytes recorded in KCS_LOG_BUF[0..KCS_LOG_IDX-1]
; Adds a CR+LF at the end for readability
; Input:  none
; Output: none
; Modifies: A, X
;-----------------------------------------------------
KCS_DUMP_LOG:
    LDX #0
@loop:
    CPX KCS_LOG_IDX
    BEQ @done
    LDA KCS_LOG_BUF, X   ; raw X count byte
    JSR KCS_PRINT_HEX    ; print as 2 hex digits
    LDA #' '
    JSR CHROUT
    INX
    BRA @loop
@done:
    LDA #$0D
    JSR CHROUT
    LDA #$0A
    JSR CHROUT
    RTS

; Print A as two uppercase hex digits, clobbers A
KCS_PRINT_HEX:
    PHA
    LSR A
    LSR A
    LSR A
    LSR A                ; high nibble
    JSR @nibble
    PLA
    AND #$0F             ; low nibble
    ; fall through
@nibble:
    CMP #10
    BCC @digit
    ADC #6               ; carry=1 from CMP, so effective +7: '0'+10+7='A' ✓
@digit:
    ADC #'0'
    JMP CHROUT