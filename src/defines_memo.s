; configuration
CONFIG_2A := 1

CONFIG_SCRTCH_ORDER := 2

; zero page
ZP_START0 = $00
ZP_START1 = $02
ZP_START2 = $0C
ZP_START3 = $62
ZP_START3A = $6D
ZP_START4 = $6F

; KCS zero page block ($F4-$F9, just below STACK_TOP)
ZP_KCS_START = $F4

; RAM scratch for binary load/run ($0200-$0203, free between stack and input buffer)
RW_JUMP_LO   = $0200    ; jump target address, lo byte  (written by KCS_LOAD)
RW_JUMP_HI   = $0201    ; jump target address, hi byte  (written by KCS_LOAD)
RW_DEFAULT_LO = $0202   ; backup of default address, lo byte (written by read_write.s)
RW_DEFAULT_HI = $0203   ; backup of default address, hi byte (written by read_write.s)

; extra/override ZP variables
USR := GORESTART

; constants
SPACE_FOR_GOSUB := $3E
STACK_TOP := $FA
WIDTH := 40
WIDTH2 := 30
RAMSTART2 := $0400
