/*
 * kcs.h — Low-level KCS encoder & decoder.
 *
 * Decoder: edge-triggered ISR on PIN_KCS_IN feeds half-period classifications
 * into a ring buffer.  serviceDecode(), called from loop(), pulls them out,
 * groups them by run length into bits, and assembles UART frames.  Each
 * complete byte is delivered to a user-supplied ByteSink callback.
 *
 * Encoder: bit-bangs PIN_KCS_OUT with direct port toggling and
 * delayMicroseconds() at the half-period level.
 */

#ifndef MEMO1SD_KCS_H
#define MEMO1SD_KCS_H

#include <Arduino.h>

namespace Kcs {

// Receive a fully framed byte.  Return false to abort the current block and
// reset the bit-level FSM back to leader-hunt mode (used to terminate after
// the checksum byte, or to bail on a framing/format error).
using ByteSink = bool (*)(uint8_t byte);

// Why the decoder gave up on a partial block.
enum AbortReason : uint8_t {
  ABORT_FRAMING,              // a UART stop bit was not '1'
  ABORT_TIMEOUT_AFTER_LEADER, // leader locked, but no start bit arrived
  ABORT_TIMEOUT_MID_BYTE,     // bytes started arriving, then the line went quiet
};

// Notify the session that a partially-received block has been abandoned.
// The session should close any open file and discard partial state.
using AbortCallback = void (*)(AbortReason reason);

// ---- Decoder ---------------------------------------------------------------

void beginDecode(ByteSink sink, AbortCallback onAbort);
void endDecode();
void serviceDecode();          // call from loop()

// Edge event: returns true exactly once after the bit-level FSM transitions
// from LEADER_HUNT to LEADER_LOCKED (i.e. we have just seen a sustained
// leader and are about to start receiving bytes).  The session uses this
// signal to pre-open the SD file before the first data byte arrives, while
// the rest of the leader (multiple seconds) is still playing out.
bool consumeLeaderLockedEvent();

// Diagnostics from the most recent ABORT_FRAMING event.
//   lastFailFramePos()  -> 9 if first stop bit failed, 10 if second
//   lastFailFrameByte() -> the 8 data bits that had been clocked in before
//                          the stop check failed (most-recent attempted byte)
uint8_t lastFailFramePos();
uint8_t lastFailFrameByte();

// Volume diagnostics — running counters since beginDecode().
//   totalEdges()  -> every edge the ISR saw (regardless of classification)
//   totalDrops()  -> edges dropped because the ring buffer was full
//   totalBits()   -> bits delivered to the bit-level FSM by run-length grouping
// Useful for distinguishing "signal really stopped" (totalEdges flatlines)
// from "signal kept coming but the decoder got lost" (totalEdges keeps
// climbing while totalBits or sinkByte calls don't).
uint32_t totalEdges();
uint16_t totalDrops();
uint32_t totalBits();

// ---- Encoder ---------------------------------------------------------------

void beginEncode();
void endEncode();
void emitSilenceMs(uint16_t ms);
void emitBit(uint8_t bit);
void emitByte(uint8_t b);
void emitMarkBits(uint16_t count);

}  // namespace Kcs

#endif  // MEMO1SD_KCS_H
