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

; KCS zero page block ($F4-$FA, just below STACK_TOP)
ZP_KCS_START  = $F4
KCS_OUT_STATE = ZP_KCS_START     ; $F4 - current D0 output level
KCS_START_LO  = ZP_KCS_START + 1 ; $F5 - save block start address, low byte
KCS_START_HI  = ZP_KCS_START + 2 ; $F6 - save block start address, high byte
KCS_LEN_LO    = ZP_KCS_START + 3 ; $F7 - save block length, low byte
KCS_LEN_HI    = ZP_KCS_START + 4 ; $F8 - save block length, high byte
KCS_CHECKSUM  = ZP_KCS_START + 5 ; $F9 - XOR checksum accumulator
KCS_LOG_IDX   = $FB               ; debug bit log write index (above STACK_TOP, safe during load)
KCS_LAST_X    = $FC               ; debug: raw X count from last KCS_MEASURE_HALF call

; KCS bit log: 128 bytes in RAM between RW block and input buffer
KCS_LOG_BUF   = $0204             ; $0204-$027F: '0'/'1' per received bit + 'S' per start bit

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
