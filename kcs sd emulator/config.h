/*
 * config.h — pin map, KCS timing constants, block format constants.
 *
 * Memo1SD: Arduino Nano interface between the Memo-1's cassette I/O and an
 * SD card.  All shared compile-time constants live here so both kcs.* and
 * session.* see the same values.
 */

#ifndef MEMO1SD_CONFIG_H
#define MEMO1SD_CONFIG_H

#include <Arduino.h>

// ----------------------------------------------------------------------------
// Pin assignments (Arduino Nano / ATmega328P)
//
// Layout chosen to (a) put the LOAD button right next to the GND between
// D2 and RST, and (b) cluster the SD module on the right column near the
// top — D10 (CS), D11 (MOSI), D12 (MISO), D13 (SCK).  D13 has to come
// from the left column; one jumper across the top of the Nano.
// ----------------------------------------------------------------------------

constexpr uint8_t PIN_LOAD_BTN   = 2;   // active-low pushbutton, internal pull-up
constexpr uint8_t PIN_KCS_IN     = 3;   // INT1 — Memo-1 latch out (square wave)
constexpr uint8_t PIN_KCS_OUT    = 4;   // PD4  — Memo-1 buffer in (square wave)
constexpr uint8_t PIN_STATUS_LED = 6;
constexpr uint8_t PIN_SD_CS      = 10;  // SD: MOSI=11, MISO=12, SCK=13 (hardware SPI)

// Direct port toggle for KCS_OUT (writing 1 to PINx toggles PORTx on AVR)
#define KCS_OUT_TOGGLE() (PIND = (1 << 4))   // toggle PD4 (D4)

// ----------------------------------------------------------------------------
// KCS timing (300 baud)
//   bit '1' = 8 cycles of 2400 Hz = 16 half-periods of ~208.33 us each
//   bit '0' = 4 cycles of 1200 Hz =  8 half-periods of ~416.67 us each
//   each bit is therefore exactly 1 / 300 s = 3333.33 us
// ----------------------------------------------------------------------------

constexpr uint16_t HALF_2400_US     = 208;   // floor(208.33)
constexpr uint16_t HALF_1200_US     = 417;   // round(416.67)

// Decoder classification thresholds (microseconds, on the receive side)
constexpr uint16_t HALF_MIN_US      = 80;    // shorter -> noise spike, drop
constexpr uint16_t HALF_THRESH_US   = 313;   // midpoint between 208 and 417
constexpr uint16_t HALF_MAX_US      = 700;   // longer  -> gap / silence

constexpr uint8_t  HALVES_PER_1     = 16;
constexpr uint8_t  HALVES_PER_0     = 8;

// UART framing: 1 start (0) + 8 data (LSB first) + 2 stop (1,1) = 11 bits
constexpr uint8_t  FRAME_BITS       = 11;

// Decoder timeouts
constexpr uint32_t MID_BLOCK_TIMEOUT_US = 1000000UL;  // 1 s of silence mid-block -> abort
constexpr uint32_t RUN_FLUSH_IDLE_US    = 5000UL;     // 5 ms idle -> flush pending half-period run

// ----------------------------------------------------------------------------
// Block format on the wire
// ----------------------------------------------------------------------------

constexpr uint8_t  MAGIC_0          = 0x4D;     // 'M'
constexpr uint8_t  MAGIC_1          = 0x31;     // '1'
constexpr uint16_t LEADER_BITS      = 1500;     // ~5 s of mark at 300 baud
constexpr uint16_t MIN_LEADER_BITS  = 300;      // ~1 s minimum to lock
constexpr uint16_t MAX_DATA_LEN     = 24576;    // 24 KB cap

// ----------------------------------------------------------------------------
// SD filenames (8.3 — SD library does not support long names by default)
// ----------------------------------------------------------------------------

constexpr const char *BIN_FILENAME  = "PROG.BIN";
constexpr const char *TMP_FILENAME  = "TEMP.BIN";   // staging file during reception
constexpr const char *TXT_FILENAME  = "PROG.TXT";

// ----------------------------------------------------------------------------
// Encode-side silence padding around a block
// ----------------------------------------------------------------------------

constexpr uint16_t SILENCE_MS       = 500;

#endif  // MEMO1SD_CONFIG_H
