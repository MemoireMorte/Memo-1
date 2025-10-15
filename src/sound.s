.segment "CODE"

.ifdef MEMO

TONE:
    JSR FRMEVL
    JSR MKINT

    ; Fast way to check if FAC is zero
    LDA FAC+4
    ORA FAC+3
    BEQ @tone_done

    LDA FAC+4
    STA VIA_T1CL
    LDA FAC+3
    STA VIA_T1CH

    LDA #$C0   ; Timer 1 in continuous mode, square wave, count at 1MHz
    STA VIA_ACR
    RTS

@tone_done:
    LDA #0
    STA VIA_ACR   ; Disable timer
    RTS

.endif