/*
 * session.h — High-level SAVE / LOAD orchestration on top of Kcs::*.
 *
 * The Session module owns the block-level FSM (magic / addr / len / data /
 * checksum), the SD I/O for both directions, and the small text sidecar that
 * records the program's start address and length alongside the binary.
 *
 * Wire protocol it implements (matches bin2memo1.py / memo12bin.py):
 *
 *   [silence 0.5s]
 *   [leader]      1500 × 1-bits  (~5 s of 2400 Hz)
 *   [magic]       0x4D 0x31  ('M', '1')
 *   [start addr]  2 bytes, little-endian
 *   [length]      2 bytes, little-endian
 *   [data]        <length> bytes
 *   [checksum]    1 byte, XOR of data bytes only (header excluded)
 *   [silence 0.5s]
 *
 * On SD:
 *   PROG.BIN  raw <length> bytes of data only (no header)
 *   PROG.TXT  two lines:  addr=0x<HHHH>  /  len=0x<HHHH>
 */

#ifndef MEMO1SD_SESSION_H
#define MEMO1SD_SESSION_H

#include <Arduino.h>

namespace Session {

enum Result : uint8_t {
  RES_NONE,
  RES_SUCCESS,
  RES_ERROR,
};

// Why the most recent SAVE failed (only meaningful if lastResult()==RES_ERROR).
enum FailReason : uint8_t {
  FAIL_NONE,
  FAIL_MAGIC,                 // first byte after leader was not 'M' / 'M' followed by '1'
  FAIL_LENGTH,                // length field was 0 or > MAX_DATA_LEN
  FAIL_FRAME,                 // a stop bit was not '1' (UART framing error)
  FAIL_CHECKSUM,              // XOR of received data did not match trailing byte
  FAIL_TIMEOUT_AFTER_LEADER,  // leader locked but no start bit ever arrived
  FAIL_TIMEOUT_MID_BYTE,      // bytes started arriving then the line went silent
  FAIL_FILE,                  // SD I/O error (open / write)
};

// ---- Listening (SAVE path) -------------------------------------------------

void       beginListening();        // arm the KCS decoder
void       serviceListen();         // drive decode forward; call from loop()
Result     lastResult();            // last completed save outcome
FailReason lastFailReason();        // why it failed (if RES_ERROR)
uint16_t   lastBytesReceived();     // # of fully decoded bytes before the failure
const char *lastBlockStateName();   // block FSM state at time of failure
uint16_t   lastDecodedAddr();       // addr field from the header (if reached)
uint16_t   lastDecodedLength();     // length field from the header (if reached)
uint16_t   lastAddr();
uint16_t   lastLength();
void       clearResult();

// ---- Transmitting (LOAD path) ----------------------------------------------

bool     beginTransmit();           // false if PROG.BIN/PROG.TXT missing/invalid
bool     serviceTransmit();         // returns true once transmission completes

}  // namespace Session

#endif  // MEMO1SD_SESSION_H
