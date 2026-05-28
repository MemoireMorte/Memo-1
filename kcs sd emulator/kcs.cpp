/*
 * kcs.cpp — KCS encoder & decoder for Memo-1 cassette I/O.
 *
 * Decoder design:
 *   - Pin-change ISR on PIN_KCS_IN captures micros() at every edge.
 *   - Each interval is classified SHORT / LONG / NONE relative to the
 *     midpoint between the two ideal half-period lengths.
 *   - The ISR pushes classifications into a power-of-two ring buffer.
 *   - serviceDecode() pulls from the ring on the main loop side and
 *     groups consecutive same-class entries into bits:
 *       16 SHORT half-periods -> one '1' bit
 *        8 LONG  half-periods -> one '0' bit
 *     Periodic "early" emission keeps the long leader (24000 SHORTs)
 *     from stalling the FSM, while a round-to-nearest flush at run
 *     boundaries absorbs noise.
 *   - Bits are fed into a UART-frame FSM (start + 8 LSB-first + 2 stop)
 *     which calls the user-supplied ByteSink for each complete byte.
 *   - A mid-block silence timeout aborts a stuck partial transfer.
 *
 * Encoder design:
 *   - Bit-banged on PD4 (D4) using direct PINx-write toggling and
 *     delayMicroseconds().  No Timer1 / no encoder ISR.  Timing error
 *     vs. ideal is < 0.2% per bit, well inside KCS tolerance.
 */

#include "kcs.h"
#include "config.h"

namespace Kcs {

// ============================================================================
// DECODER
// ============================================================================

namespace {

// ---- Half-period classification --------------------------------------------

constexpr uint8_t HALF_NONE  = 0;
constexpr uint8_t HALF_SHORT = 1;     // ~208 us  (½-period of 2400 Hz)
constexpr uint8_t HALF_LONG  = 2;     // ~417 us  (½-period of 1200 Hz)

// ---- Ring buffer (ISR producer, loop consumer) -----------------------------
//
// 256 entries × 208 µs/entry = ~53 ms of headroom.  serviceListen() flushes
// dataBuf to the SD card AFTER serviceDecode() returns, so the ring has its
// full capacity available during every SD write.  The largest blocking event
// we expect is a FAT cluster allocation on the first write to a new file
// (~20–50 ms on most cards), which fits comfortably within 53 ms.
//
// Sector-overwrite stalls (erase+program) could last seconds on cheap cards,
// but we avoid those by never pre-writing dummy data to TEMP.BIN — every
// sector written during reception is a fresh write to an erased page, which
// completes in ~5 ms.
//
// Indices stay uint8_t so reads from the ISR/main split are naturally atomic
// on AVR (8-bit loads/stores are single instructions).

constexpr uint16_t RING_SIZE = 256;
constexpr uint8_t  RING_MASK = 0xFF;       // = RING_SIZE - 1, fits uint8_t

volatile uint8_t  halfRing[RING_SIZE];
volatile uint8_t  ringHead = 0;
volatile uint8_t  ringTail = 0;
volatile uint32_t lastEdgeMicros = 0;

// ---- Run-length state (loop side) ------------------------------------------

uint8_t  curRunType  = HALF_NONE;
uint16_t curRunCount = 0;

// ---- Bit-level FSM ---------------------------------------------------------

enum BitState : uint8_t {
  BIT_LEADER_HUNT,    // counting 1-bits, looking for sustained leader
  BIT_LEADER_LOCKED,  // locked on leader, waiting for first 0 (start bit)
  BIT_IN_FRAME,       // collecting 11 bits of a UART frame
};

BitState bitState   = BIT_LEADER_HUNT;
uint16_t leaderRun  = 0;
uint8_t  framePos   = 0;     // 0 = awaiting start; 1..8 = data; 9..10 = stop
uint8_t  frameByte  = 0;

// ---- Callbacks / events -----------------------------------------------------

ByteSink      g_sink            = nullptr;
AbortCallback g_onAbort         = nullptr;
bool          g_decoding        = false;
bool          g_leaderLockedEvt = false;   // set on LEADER_HUNT->LEADER_LOCKED

// Snapshot of state at the most recent ABORT_FRAMING event.
uint8_t       g_failFramePos    = 0;
uint8_t       g_failFrameByte   = 0;

// Volume counters since beginDecode().
volatile uint32_t g_totalEdges  = 0;     // every ISR invocation
volatile uint16_t g_totalDrops  = 0;     // ISR couldn't enqueue (ring full)
uint32_t          g_totalBits   = 0;     // bits delivered to feedBit()

// ---- ISR --------------------------------------------------------------------

void onEdgeISR() {
  uint32_t now = micros();
  uint32_t dt  = now - lastEdgeMicros;
  lastEdgeMicros = now;
  g_totalEdges++;

  uint8_t cls;
  if (dt < HALF_MIN_US || dt > HALF_MAX_US) cls = HALF_NONE;
  else if (dt < HALF_THRESH_US)             cls = HALF_SHORT;
  else                                       cls = HALF_LONG;

  uint16_t nextHead = (ringHead + 1) & RING_MASK;
  if (nextHead != ringTail) {
    halfRing[ringHead] = cls;
    ringHead = nextHead;
  } else {
    g_totalDrops++;
  }
}

// ---- Bit-level FSM ----------------------------------------------------------

inline void resetBitFsm() {
  bitState  = BIT_LEADER_HUNT;
  leaderRun = 0;
  framePos  = 0;
  frameByte = 0;
}

void feedBit(uint8_t bit) {
  g_totalBits++;
  switch (bitState) {
    case BIT_LEADER_HUNT:
      if (bit == 1) {
        if (leaderRun < 0xFFFF) leaderRun++;
        if (leaderRun >= MIN_LEADER_BITS) {
          bitState = BIT_LEADER_LOCKED;
          g_leaderLockedEvt = true;       // tell session to pre-open SD file
        }
      } else {
        leaderRun = 0;
      }
      break;

    case BIT_LEADER_LOCKED:
      if (bit == 0) {
        // First start bit of the magic byte.
        framePos  = 1;
        frameByte = 0;
        bitState  = BIT_IN_FRAME;
      }
      // bit==1 -> still inside leader, ignore.
      break;

    case BIT_IN_FRAME:
      if (framePos == 0) {
        // Awaiting next start bit (between bytes).
        if (bit == 0) {
          framePos  = 1;
          frameByte = 0;
        }
        // Stray 1 -> ignore (shouldn't happen on a clean stream).
      } else if (framePos <= 8) {
        // Data bit, LSB first.
        if (bit) frameByte |= (uint8_t)(1U << (framePos - 1));
        framePos++;
      } else {
        // Stop bit (framePos = 9 or 10).
        if (bit != 1) {
          // Capture diagnostics BEFORE we reset state.  framePos tells us
          // which stop bit failed; frameByte is the 8 data bits we had
          // already clocked in (i.e. the byte we *would* have delivered).
          g_failFramePos  = framePos;
          g_failFrameByte = frameByte;
          if (g_onAbort) g_onAbort(ABORT_FRAMING);
          resetBitFsm();
          return;
        }
        framePos++;
        if (framePos == FRAME_BITS) {
          uint8_t b = frameByte;
          framePos  = 0;
          frameByte = 0;
          if (g_sink) {
            if (!g_sink(b)) {
              // Sink terminated this block (success or fatal error).
              resetBitFsm();
            }
          }
        }
      }
      break;
  }
}

// ---- Run-length flushing ----------------------------------------------------

inline void emitBitsForRun(uint8_t type, uint16_t count, bool exact) {
  // exact=true  -> floor-divide (used for periodic mid-run flush)
  // exact=false -> round-to-nearest (used at run-boundary flush)
  uint8_t per   = (type == HALF_SHORT) ? HALVES_PER_1 : HALVES_PER_0;
  uint16_t nbits = exact ? (count / per)
                         : ((count + (per >> 1)) / per);
  uint8_t v = (type == HALF_SHORT) ? 1 : 0;
  while (nbits--) feedBit(v);
}

void onHalf(uint8_t cls) {
  if (cls == HALF_NONE) {
    // Noise spike or long gap -> flush whatever's pending and reset.
    if (curRunCount > 0) {
      emitBitsForRun(curRunType, curRunCount, /*exact=*/false);
      curRunCount = 0;
      curRunType  = HALF_NONE;
    }
    return;
  }

  if (cls != curRunType) {
    if (curRunCount > 0) emitBitsForRun(curRunType, curRunCount, /*exact=*/false);
    curRunType  = cls;
    curRunCount = 0;
  }
  curRunCount++;

  // Periodic flush so a 5 s leader doesn't sit in the buffer for 5 s.
  uint8_t per = (curRunType == HALF_SHORT) ? HALVES_PER_1 : HALVES_PER_0;
  if (curRunCount >= per) {
    feedBit(curRunType == HALF_SHORT ? 1 : 0);
    curRunCount -= per;
  }
}

}  // anonymous namespace

// ---- Public decoder API -----------------------------------------------------

void beginDecode(ByteSink sink, AbortCallback onAbort) {
  noInterrupts();
  ringHead = 0;
  ringTail = 0;
  curRunType  = HALF_NONE;
  curRunCount = 0;
  resetBitFsm();
  lastEdgeMicros    = micros();
  g_sink            = sink;
  g_onAbort         = onAbort;
  g_decoding        = true;
  g_leaderLockedEvt = false;
  g_totalEdges      = 0;
  g_totalDrops      = 0;
  g_totalBits       = 0;
  interrupts();

  // INPUT_PULLUP keeps the line idle-HIGH when the Memo-1's latch isn't
  // actively driving it, preventing floating-pin EMI from looking like a
  // sustained burst of '1' bits and spuriously locking the leader.  The
  // Memo-1's 74-series push-pull output overrides the ~30 kOhm pull-up
  // easily, so the real KCS signal is unaffected.
  pinMode(PIN_KCS_IN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_KCS_IN), onEdgeISR, CHANGE);
}

bool consumeLeaderLockedEvent() {
  if (g_leaderLockedEvt) {
    g_leaderLockedEvt = false;
    return true;
  }
  return false;
}

uint8_t lastFailFramePos()  { return g_failFramePos; }
uint8_t lastFailFrameByte() { return g_failFrameByte; }

uint32_t totalEdges() {
  uint32_t v;
  noInterrupts();
  v = g_totalEdges;
  interrupts();
  return v;
}

uint16_t totalDrops() {
  uint16_t v;
  noInterrupts();
  v = g_totalDrops;
  interrupts();
  return v;
}

uint32_t totalBits() { return g_totalBits; }

void endDecode() {
  detachInterrupt(digitalPinToInterrupt(PIN_KCS_IN));
  g_decoding = false;
  g_sink     = nullptr;
  g_onAbort  = nullptr;
}

void serviceDecode() {
  if (!g_decoding) return;

  // Drain the ring buffer.
  while (ringTail != ringHead) {
    uint8_t cls = halfRing[ringTail];
    ringTail = (ringTail + 1) & RING_MASK;
    onHalf(cls);
  }

  // Snapshot lastEdgeMicros atomically.
  uint32_t lastEdge;
  noInterrupts();
  lastEdge = lastEdgeMicros;
  interrupts();

  uint32_t idle = micros() - lastEdge;

  // If we're mid-run and the line has been quiet for a few ms, the run is
  // really over (e.g. trailing stop bits before silence) -> flush.
  if (curRunCount > 0 && idle > RUN_FLUSH_IDLE_US) {
    emitBitsForRun(curRunType, curRunCount, /*exact=*/false);
    curRunCount = 0;
    curRunType  = HALF_NONE;
  }

  // If we're past the leader (mid-block) and the line has been silent for
  // a long time, the transfer was interrupted -> abort and re-arm.  Split
  // the reason by where we were stuck so the user can tell the difference
  // between "leader locked but no data ever followed" (likely a noisy or
  // intermittent signal -- e.g. crosstalk with no real source) and "data
  // started but then stopped" (cable popped out mid-transfer, or the
  // Memo-1's KCS routine doesn't match our framing assumptions).
  if ((bitState == BIT_LEADER_LOCKED || bitState == BIT_IN_FRAME)
      && idle > MID_BLOCK_TIMEOUT_US) {
    AbortReason r = (bitState == BIT_LEADER_LOCKED)
                      ? ABORT_TIMEOUT_AFTER_LEADER
                      : ABORT_TIMEOUT_MID_BYTE;
    if (g_onAbort) g_onAbort(r);
    resetBitFsm();
  }
}


// ============================================================================
// ENCODER (bit-banged on PD4 = D4)
// ============================================================================

void beginEncode() {
  pinMode(PIN_KCS_OUT, OUTPUT);
  digitalWrite(PIN_KCS_OUT, LOW);
}

void endEncode() {
  digitalWrite(PIN_KCS_OUT, LOW);
}

void emitSilenceMs(uint16_t ms) {
  digitalWrite(PIN_KCS_OUT, LOW);
  delay(ms);
}

void emitBit(uint8_t bit) {
  if (bit) {
    // 8 cycles of 2400 Hz = 16 toggles, half-period 208 us.
    for (uint8_t i = 0; i < HALVES_PER_1; i++) {
      KCS_OUT_TOGGLE();
      delayMicroseconds(HALF_2400_US);
    }
  } else {
    // 4 cycles of 1200 Hz = 8 toggles, half-period 417 us.
    for (uint8_t i = 0; i < HALVES_PER_0; i++) {
      KCS_OUT_TOGGLE();
      delayMicroseconds(HALF_1200_US);
    }
  }
}

void emitByte(uint8_t b) {
  emitBit(0);                                // start
  for (uint8_t i = 0; i < 8; i++) {          // data, LSB first
    emitBit((b >> i) & 1);
  }
  emitBit(1);                                // stop 1
  emitBit(1);                                // stop 2
}

void emitMarkBits(uint16_t count) {
  while (count--) emitBit(1);
}

}  // namespace Kcs
