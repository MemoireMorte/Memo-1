

; Frequencies for notes (approximate, with 1MHz clock)
; Octave 2
; #$EEE = DO 130.81Hz ; 1000000 / 130.81 = 7644.53 ; 7644.53 / 2 = 3822.28 = $EEE
; #$E18 = DO# 138.59Hz ; 1000000 / 138.59 = 7211.48 ; 7211.48 / 2 = 3605.74 = $E16
; #$D4D = RE 146.83Hz ; 1000000 / 146.83 = 6810.50 ; 6810.50 / 2 = 3405.25 = $D4D
; #$C8E = RE# 155.56Hz ; 1000000 / 155.56 = 6428.26 ; 6428.26 / 2 = 3214.13 = $C8E
; #$BDA = MI 164.81Hz ; 1000000 / 164.81 = 6067.48 ; 6067.48 / 2 = 3033.74 = $BDA
; #$B2F = FA 174.61Hz ; 1000000 / 174.61 = 5726.92 ; 5726.92 / 2 = 2863.46 = $B2F
; #$A8F = FA# 185.00Hz ; 1000000 / 185.00 = 5405.49 ; 5405.49 / 2 = 2702.74 = $A8F
; #$9F7 = SOL 196.00Hz ; 1000000 / 196.00 = 5102.12 ; 5102.12 / 2 = 2551.06 = $9F7
; #$968 = SOL# 207.65Hz ; 1000000 / 207.65 = 4815.75 ; 4815.75 / 2 = 2407.87 = $968
; #$8E1 = LA 220Hz ; 1000000 / 220 = 4545.45 ; 4545.45 / 2 = 2272.73 = $8E1
; #$861 = LA# 233.08Hz ; 1000000 / 233.08 = 4290.35 ; 4290.35 / 2 = 2145.18 = $861
; #$7E9 = SI 246.94Hz ; 1000000 / 246.94 = 4049.55 ; 4049.55 / 2 = 2024.78 = $7E9

PLAY_TONE_DO2:
                ldx #$EE
                ldy #$0E
                jsr PLAY_TONE
                rts
PLAY_TONE_DO_SHARP2:
                ldx #$18
                ldy #$0E
                jsr PLAY_TONE
                rts
PLAY_TONE_RE2:
                ldx #$4D
                ldy #$0D
                jsr PLAY_TONE
                rts
PLAY_TONE_RE_SHARP2:
                ldx #$8E
                ldy #$0C
                jsr PLAY_TONE
                rts
PLAY_TONE_MI2:
                ldx #$DA
                ldy #$0B
                jsr PLAY_TONE
                rts
PLAY_TONE_FA2:
                ldx #$2F
                ldy #$0B
                jsr PLAY_TONE
                rts
PLAY_TONE_FA_SHARP2:
                ldx #$8F
                ldy #$0A
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL2:
                ldx #$F7
                ldy #$09
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL_SHARP2:
                ldx #$68
                ldy #$09
                jsr PLAY_TONE
                rts
PLAY_TONE_LA2:
                ldx #$E1
                ldy #$08
                jsr PLAY_TONE
                rts
PLAY_TONE_LA_SHARP2:
                ldx #$61
                ldy #$08
                jsr PLAY_TONE
                rts
PLAY_TONE_SI2:
                ldx #$E9
                ldy #$07
                jsr PLAY_TONE
                rts

; Octave 3
; #$777 = DO 261.63Hz ; 1000000 / 261.63 = 3822.66 ; 3822.66 / 2 = 1911.33 = $777
; #$70C = DO# 277.18Hz ; 1000000 / 277.18 = 3615.75 ; 3615.75 / 2 = 1807.87 = $70C
; #$6A7 = RE 293.66Hz ; 1000000 / 293.66 = 3405.06 ; 3405.06 / 2 = 1702.53 = $6A7
; #$647 = RE# 311.13Hz ; 1000000 / 311.13 = 3214.29 ; 3214.29 / 2 = 1607.14 = $647
; #$5ED = MI 329.63Hz ; 1000000 / 329.63 = 3033.96 ; 3033.96 / 2 = 1516.98 = $5ED
; #$598 = FA 349.23Hz ; 1000000 / 349.23 = 2864.66 ; 2864.66 / 2 = 1432.33 = $598
; #$547 = FA# 369.99Hz ; 1000000 / 369.99 = 2700.00 ; 2700.00 / 2 = 1350.00 = $547
; #$4FC = SOL 392.00Hz ; 1000000 / 392.00 = 2551.02 ; 2551.02 / 2 = 1275.51 = $4FC
; #$4B4 = SOL# 415.30Hz ; 1000000 / 415.30 = 2405.88 ; 2405.88 / 2 = 1202.94 = $4B4
; #$470 = LA 440Hz ; 1000000 / 440 = 2272.73 ; 2272.73 / 2 = 1136.36 = $470
; #$431 = LA# 466.16Hz ; 1000000 / 466.16 = 2145.45 ; 2145.45 / 2 = 1072.73 = $431
; #$3F4 = SI 493.88Hz ; 1000000 / 493.88 = 2020.41 ; 2020.41 / 2 = 1010.20 = $3F4

PLAY_TONE_DO3:
                ldx #$77
                ldy #$07
                jsr PLAY_TONE
                rts
PLAY_TONE_DO_SHARP3:
                ldx #$0C
                ldy #$07
                jsr PLAY_TONE
                rts
PLAY_TONE_RE3:
                ldx #$A7
                ldy #$06
                jsr PLAY_TONE
                rts
PLAY_TONE_RE_SHARP3:
                ldx #$47
                ldy #$06
                jsr PLAY_TONE
                rts
PLAY_TONE_MI3:
                ldx #$ED
                ldy #$05
                jsr PLAY_TONE
                rts
PLAY_TONE_FA3:
                ldx #$98
                ldy #$05
                jsr PLAY_TONE
                rts
PLAY_TONE_FA_SHARP3:
                ldx #$47
                ldy #$05
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL3:
                ldx #$FC
                ldy #$04
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL_SHARP3:
                ldx #$B4
                ldy #$04
                jsr PLAY_TONE
                rts
PLAY_TONE_LA3:
                ldx #$70
                ldy #$04
                jsr PLAY_TONE
                rts
PLAY_TONE_LA_SHARP3:
                ldx #$31
                ldy #$04
                jsr PLAY_TONE
                rts
PLAY_TONE_SI3:
                ldx #$F4
                ldy #$03
                jsr PLAY_TONE
                rts

; Octave 4
; #$3BC = DO 523.25Hz ; 1000000 / 523.25 = 1911.33 ; 1911.33 / 2 = 955.66 = $3BC
; #$388 = DO# 554.37Hz ; 1000000 / 554.37 = 1807.87 ; 1807.87 / 2 = 903.94 = $388
; #$353 = RE 587.33Hz ; 1000000 / 587.33 = 1702.53 ; 1702.53 / 2 = 851.27 = $353
; #$324 = RE# 622.25Hz ; 1000000 / 622.25 = 1607.14 ; 1607.14 / 2 = 803.57 = $324
; #$2F6 = MI 659.25Hz ; 1000000 / 659.25 = 1516.98 ; 1516.98 / 2 = 758.49 = $2F6
; #$2CC = FA 698.46Hz ; 1000000 / 698.46 = 1432.33 ; 1432.33 / 2 = 716.16 = $2CC
; #$2A3 = FA# 739.99Hz ; 1000000 / 739.99 = 1350.00 ; 1350.00 / 2 = 675.00 = $2A3
; #$27E = SOL 783.99Hz ; 1000000 / 783.99 = 1275.51 ; 1275.51 / 2 = 637.76 = $27E
; #$259 = SOL# 830.61Hz ; 1000000 / 830.61 = 1202.94 ; 1202.94 / 2 = 601.47 = $259
; #$238 = LA 880Hz ; 1000000 / 880 = 1136.36 ; 1136.36 / 2 = 568.18 = $238
; #$218 = LA# 932.33Hz ; 1000000 / 932.33 = 1072.73 ; 1072.73 / 2 = 536.36 = $218
; #$1F9 = SI 987.77Hz ; 1000000 / 987.77 = 1010.20 ; 1010.20 / 2 = 505.10 = $1F9

PLAY_TONE_DO4:
                ldx #$BC
                ldy #$03
                jsr PLAY_TONE
                rts
PLAY_TONE_DO_SHARP4:
                ldx #$88
                ldy #$03
                jsr PLAY_TONE
                rts
PLAY_TONE_RE4:
                ldx #$53
                ldy #$03
                jsr PLAY_TONE
                rts
PLAY_TONE_RE_SHARP4:
                ldx #$24
                ldy #$03
                jsr PLAY_TONE
                rts
PLAY_TONE_MI4:
                ldx #$F6
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_FA4:
                ldx #$CC
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_FA_SHARP4:
                ldx #$A3
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL4:
                ldx #$7E
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL_SHARP4:
                ldx #$59
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_LA4:
                ldx #$38
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_LA_SHARP4:
                ldx #$18
                ldy #$02
                jsr PLAY_TONE
                rts
PLAY_TONE_SI4:
                ldx #$F9
                ldy #$01
                jsr PLAY_TONE
                rts

; Octave 5
; #$1DE = DO 1046.50Hz ; 1000000 / 1046.50 = 955.66 ; 955.66 / 2 = 477.83 = $1DE
; #$1C4 = DO# 1108.73Hz ; 1000000 / 1108.73 = 903.94 ; 903.94 / 2 = 451.97 = $1C4
; #$1AA = RE 1174.66Hz ; 1000000 / 1174.66 = 851.27 ; 851.27 / 2 = 425.63 = $1AA
; #$192 = RE# 1244.51Hz ; 1000000 / 1244.51 = 803.57 ; 803.57 / 2 = 401.79 = $192
; #$17B = MI 1318.51Hz ; 1000000 / 1318.51 = 758.49 ; 758.49 / 2 = 379.24 = $17B
; #$166 = FA 1396.91Hz ; 1000000 / 1396.91 = 716.16 ; 716.16 / 2 = 358.08 = $166
; #$152 = FA# 1479.98Hz ; 1000000 / 1479.98 = 675.00 ; 675.00 / 2 = 337.50 = $152
; #$13F = SOL 1567.98Hz ; 1000000 / 1567.98 = 637.76 ; 637.76 / 2 = 318.88 = $13F
; #$12D = SOL# 1661.22Hz ; 1000000 / 1661.22 = 601.47 ; 601.47 / 2 = 300.73 = $12D
; #$11C = LA 1760Hz ; 1000000 / 1760 = 568.18 ; 568.18 / 2 = 284.09 = $11C
; #$10C = LA# 1864.66Hz ; 1000000 / 1864.66 = 536.36 ; 536.36 / 2 = 268.18 = $10C
; #$0FD = SI 1975.53Hz ; 1000000 / 1975.53 = 505.10 ; 505.10 / 2 = 252.55 = $0FD

PLAY_TONE_DO5:
                ldx #$DE
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_DO_SHARP5:
                ldx #$C4
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_RE5:
                ldx #$AA
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_RE_SHARP5:
                ldx #$92
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_MI5:
                ldx #$7B
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_FA5:
                ldx #$66
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_FA_SHARP5:
                ldx #$52
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL5:
                ldx #$3F
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_SOL_SHARP5:
                ldx #$2D
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_LA5:
                ldx #$1C
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_LA_SHARP5:
                ldx #$0C
                ldy #$01
                jsr PLAY_TONE
                rts
PLAY_TONE_SI5:
                ldx #$FD
                ldy #$00
                jsr PLAY_TONE
                rts 