/*
 * Memo1SD — Arduino Nano interface between Memo-1 (6502 homebrew) cassette
 *           I/O and a micro SD card.  Replaces the unreliable cassette path
 *           with a digital tap on the latch (output) and buffer (input).
 *
 * Wire format (KCS, 300 baud, matches bin2memo1.py / memo12bin.py):
 *   [silence 0.5s] [leader 1500×1] [magic 'M' '1'] [addr LE] [len LE]
 *   [data] [checksum = XOR of data] [silence 0.5s]
 *
 * On SD:
 *   PROG.BIN  raw payload bytes
 *   PROG.TXT  addr=0x<HHHH> / len=0x<HHHH>
 *
 * Pins:
 *   D2  LOAD button  (active-low, internal pull-up, button to GND nearby)
 *   D3  KCS_IN       Memo-1 latch out  (INT1, square wave 1200/2400 Hz)
 *   D4  KCS_OUT      Memo-1 buffer in  (PD4,  square wave 1200/2400 Hz)
 *   D6  STATUS_LED
 *   D10 SD CS        (D11/D12/D13 = MOSI/MISO/SCK, hardware SPI)
 *
 * Top-level state:
 *   LISTEN    — KCS decoder armed; auto-detects a SAVE via the leader.
 *               Pressing LOAD transitions to TRANSMIT (if SD has a file).
 *   TRANSMIT  — KCS encoder is emitting the block from SD.
 *   ERROR     — solid LED for 2 s, then back to LISTEN.
 *
 * Serial console (9600) prints status messages — useful for first-boot
 * sanity checks but not required for normal operation.
 */

#include <SPI.h>
#include <SD.h>
#include "config.h"
#include "kcs.h"
#include "session.h"

enum TopState : uint8_t {
  STATE_LISTEN,
  STATE_TRANSMIT,
  STATE_ERROR,
};

static TopState topState        = STATE_LISTEN;
static uint32_t errorEnteredMs  = 0;

// Status LED blink state
static uint32_t lastLedToggleMs = 0;
static bool     ledOn           = false;

// LOAD button debouncing
static uint8_t  btnLastReading    = HIGH;
static uint32_t btnLastChangeMs   = 0;
static bool     btnPressedHandled = false;

// ----- forward decls --------------------------------------------------------

static void loopListen();
static void loopTransmit();
static void loopError();
static bool loadButtonPressed();
static void enterError(const __FlashStringHelper *why);
static void updateStatusLed();

// ============================================================================
// setup / loop
// ============================================================================

void setup() {
  pinMode(PIN_LOAD_BTN,   INPUT_PULLUP);
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  Serial.begin(9600);
  // Brief grace period for USB-serial to come up on boards that need it,
  // but don't block forever -- we want to run headless too.
  uint32_t t0 = millis();
  while (!Serial && (millis() - t0) < 1500) { /* spin */ }

  Serial.println(F("Memo1SD starting..."));

  if (!SD.begin(PIN_SD_CS)) {
    Serial.println(F("SD init failed"));
    enterError(F("SD init failed"));
    return;
  }
  Serial.println(F("SD ready"));

  Session::beginListening();
  Serial.println(F("Listening for KCS leader..."));
}

void loop() {
  switch (topState) {
    case STATE_LISTEN:    loopListen();    break;
    case STATE_TRANSMIT:  loopTransmit();  break;
    case STATE_ERROR:     loopError();     break;
  }
  updateStatusLed();
}

// ============================================================================
// LISTEN — decoder is armed; watch for completed blocks and the LOAD button.
// ============================================================================

static const __FlashStringHelper *failName(Session::FailReason r) {
  switch (r) {
    case Session::FAIL_MAGIC:                return F("bad magic (first bytes weren't 'M' '1')");
    case Session::FAIL_LENGTH:               return F("bad length (zero or > 24 KB)");
    case Session::FAIL_FRAME:                return F("UART framing error (stop bit not '1')");
    case Session::FAIL_CHECKSUM:             return F("checksum mismatch");
    case Session::FAIL_TIMEOUT_AFTER_LEADER: return F("leader locked but no start bit followed");
    case Session::FAIL_TIMEOUT_MID_BYTE:     return F("line went silent mid-transfer");
    case Session::FAIL_FILE:                 return F("SD file I/O error");
    default:                                 return F("unknown");
  }
}

static void loopListen() {
  Session::serviceListen();

  Session::Result r = Session::lastResult();
  if (r == Session::RES_SUCCESS) {
    Serial.print(F("SAVE ok: addr=0x"));
    Serial.print(Session::lastAddr(), HEX);
    Serial.print(F(", len="));
    Serial.println(Session::lastLength());
    Session::clearResult();
  } else if (r == Session::RES_ERROR) {
    Session::FailReason fr = Session::lastFailReason();
    Serial.print(F("SAVE error: "));
    Serial.println(failName(fr));
    Serial.print(F("  bytes received before fail: "));
    Serial.println(Session::lastBytesReceived());
    Serial.print(F("  block state at fail: "));
    Serial.println(Session::lastBlockStateName());
    // If we got past the header, also report what the header claimed --
    // useful for cross-checking against what the Memo-1 thinks it sent.
    if (Session::lastBytesReceived() >= 6) {
      Serial.print(F("  header said: addr=0x"));
      Serial.print(Session::lastDecodedAddr(), HEX);
      Serial.print(F(", length="));
      Serial.print(Session::lastDecodedLength());
      Serial.print(F(" -> data bytes received: "));
      Serial.print(Session::lastBytesReceived() - 6);
      Serial.print(F(" / "));
      Serial.println(Session::lastDecodedLength());
    }
    if (fr == Session::FAIL_FRAME) {
      Serial.print(F("  failed stop bit: "));
      uint8_t fp = Kcs::lastFailFramePos();
      Serial.print(fp);
      Serial.println(fp == 9 ? F(" (first stop)") : F(" (second stop)"));
      Serial.print(F("  partial byte (8 data bits decoded as): 0x"));
      Serial.println(Kcs::lastFailFrameByte(), HEX);
    }
    // Edge / bit volume — tells us whether the wire actually went silent
    // or the decoder lost sync while edges kept coming in.
    Serial.print(F("  total edges seen by ISR: "));
    Serial.println(Kcs::totalEdges());
    Serial.print(F("  ring drops (ISR couldn't enqueue): "));
    Serial.println(Kcs::totalDrops());
    Serial.print(F("  total bits delivered to FSM: "));
    Serial.println(Kcs::totalBits());
    Session::clearResult();
  }

  if (loadButtonPressed()) {
    Serial.println(F("LOAD pressed"));
    if (Session::beginTransmit()) {
      Serial.println(F("Transmitting..."));
      topState = STATE_TRANSMIT;
    } else {
      Serial.println(F("LOAD aborted: PROG.BIN/PROG.TXT missing or invalid"));
      enterError(F("no file"));
    }
  }
}

// ============================================================================
// TRANSMIT — drive the encoder phase machine.
// ============================================================================

static void loopTransmit() {
  if (Session::serviceTransmit()) {
    Serial.println(F("LOAD complete"));
    Session::beginListening();
    topState = STATE_LISTEN;
  }
}

// ============================================================================
// ERROR — solid LED for 2 s then back to LISTEN.
// ============================================================================

static void enterError(const __FlashStringHelper *why) {
  Serial.print(F("ERROR: "));
  Serial.println(why);
  topState       = STATE_ERROR;
  errorEnteredMs = millis();
}

static void loopError() {
  if (millis() - errorEnteredMs > 2000) {
    Session::beginListening();
    topState = STATE_LISTEN;
    Serial.println(F("Listening for KCS leader..."));
  }
}

// ============================================================================
// LOAD button — active-low, internal pull-up, 30 ms debounce.
// Returns true exactly once per press (on the falling edge after stability).
// ============================================================================

static bool loadButtonPressed() {
  uint8_t  reading = digitalRead(PIN_LOAD_BTN);
  uint32_t now     = millis();

  if (reading != btnLastReading) {
    btnLastReading  = reading;
    btnLastChangeMs = now;
  }

  if (now - btnLastChangeMs >= 30) {
    if (reading == LOW && !btnPressedHandled) {
      btnPressedHandled = true;
      return true;
    } else if (reading == HIGH) {
      btnPressedHandled = false;
    }
  }
  return false;
}

// ============================================================================
// Status LED:
//   LISTEN    — slow blink (1 Hz)
//   TRANSMIT  — solid on (loop is blocked inside emitBit anyway)
//   ERROR     — solid on
// ============================================================================

static void updateStatusLed() {
  if (topState == STATE_TRANSMIT || topState == STATE_ERROR) {
    digitalWrite(PIN_STATUS_LED, HIGH);
    return;
  }
  uint32_t now = millis();
  if (now - lastLedToggleMs >= 500) {
    lastLedToggleMs = now;
    ledOn = !ledOn;
    digitalWrite(PIN_STATUS_LED, ledOn ? HIGH : LOW);
  }
}
