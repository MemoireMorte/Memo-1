/*
 * session.cpp — Implementation of the SAVE / LOAD session FSMs.
 *
 * SAVE side:
 *   sinkByte() is the ByteSink registered with Kcs::beginDecode().  It
 *   walks the block FSM state by state.  Data bytes are accumulated in a
 *   RAM buffer (dataBuf) so that NO SD I/O happens inside the callback.
 *   SD writes are deferred to serviceListen() after serviceDecode() returns.
 *   When the checksum byte
 *   arrives we either commit (write PROG.TXT, mark success) or roll back
 *   (delete the partial PROG.BIN, mark error).  Either way we return
 *   false from the sink so the bit-level FSM resets to leader hunt and
 *   is ready for the next block.
 *
 *   abortDuringDecode() is the AbortCallback for mid-block silence
 *   timeout / framing error / bad magic / checksum mismatch.
 *
 * LOAD side:
 *   serviceTransmit() is a tiny phase machine (silence -> leader ->
 *   header -> data -> checksum -> silence).  Data is streamed from
 *   PROG.BIN one byte at a time; nothing is buffered in RAM other than
 *   what the SD library buffers internally.
 */

#include "session.h"
#include "config.h"
#include "kcs.h"
#include <SPI.h>
#include <SD.h>
#include <string.h>   // memmove

namespace Session {

namespace {

// ============================================================================
// SAVE state
// ============================================================================

enum BlockState : uint8_t {
  BLK_MAGIC0,
  BLK_MAGIC1,
  BLK_ADDR_LO,
  BLK_ADDR_HI,
  BLK_LEN_LO,
  BLK_LEN_HI,
  BLK_DATA,
  BLK_CHECKSUM,
};

// Data is buffered here during reception so that blkFile.write() is never
// called from inside the KCS decoder callback (sinkByte).  That callback runs
// deep inside serviceDecode(), and any SD I/O there blocks the ring drain for
// 50–200 ms, causing half-period drops that corrupt or lose the tail of the
// block.  Instead, sinkByte() only writes to RAM; the actual SD write happens
// in serviceListen() right after serviceDecode() returns, where the ring has
// a full ~53 ms of headroom before it can overflow.
//
// For files that fit entirely in RAM_BUF_SIZE bytes the write happens once at
// checksum time (zero SD blocking during reception).  For larger files a full
// RAM_BUF_SIZE-byte sector is flushed after each serviceDecode() call; the
// ring absorbs the signal that arrives during the flush.
// Flush threshold.  Keep this small: every byte saved here is a byte of
// stack the SD library can use.  The ATmega328P has only 2 KB of SRAM total;
// the SD library's call chain (SDClass::open → SdBaseFile::open →
// SdVolume::cacheRawBlock → Sd2Card::readBlock) uses ~180–200 bytes of stack,
// and the KCS ring (256 B), SdVolume cache (512 B), Serial buffers (128 B) and
// other globals leave very little room.  A RAM_BUF_SIZE of 512 exhausted the
// stack and caused SD.open() to return false on every call.
//
// 64 bytes is enough for the typical use case:
//   - Files ≤ 64 bytes : single blkFile.write() at checksum time, zero SD
//     blocking during reception.
//   - Files 65–511 bytes: intermediate blkFile.write() calls flush into
//     SdFat's own 512-byte RAM cache (pure RAM copy, ~µs, no SD card I/O).
//     The card is only written at close(), well after reception ends.
//   - Files ≥ 512 bytes: one real SD sector write per 512 bytes received,
//     fired from serviceListen() where the ring has its full 53 ms headroom
//     (256-entry ring at 208 µs/entry).
constexpr uint16_t RAM_BUF_SIZE = 64;
// The backing array is slightly larger than RAM_BUF_SIZE so that the few
// bytes sinkByte() may add after setting dataBufFlushPending (but before
// serviceDecode() returns) never overflow the buffer.  At 300 baud the ring
// holds ≤ 2 extra bytes during that window; 32 is a comfortable margin.
constexpr uint16_t RAM_BUF_CAP  = RAM_BUF_SIZE + 32;

BlockState blkState   = BLK_MAGIC0;
uint16_t   blkAddr    = 0;
uint16_t   blkLength  = 0;
uint16_t   blkRemain  = 0;
uint8_t    blkXor     = 0;
File       blkFile;

uint8_t    dataBuf[RAM_BUF_CAP];   // RAM write buffer (never call blkFile.write inside sinkByte)
uint16_t   dataBufLen  = 0;
bool       dataBufFlushPending = false;  // set when dataBuf holds a full RAM_BUF_SIZE chunk

Result     result      = RES_NONE;
FailReason failReason  = FAIL_NONE;
uint16_t   resultAddr  = 0;
uint16_t   resultLen   = 0;

// Diagnostic snapshots, captured at the moment of failure so the main loop
// can print them after the fact.
uint16_t   bytesReceivedAtFail = 0;
BlockState blockStateAtFail    = BLK_MAGIC0;
uint16_t   addrAtFail          = 0;
uint16_t   lengthAtFail        = 0;
uint16_t   bytesReceivedRunning = 0;     // running count, copied to ...AtFail on abort

const char *blockStateName(BlockState s) {
  switch (s) {
    case BLK_MAGIC0:   return "MAGIC0";
    case BLK_MAGIC1:   return "MAGIC1";
    case BLK_ADDR_LO:  return "ADDR_LO";
    case BLK_ADDR_HI:  return "ADDR_HI";
    case BLK_LEN_LO:   return "LEN_LO";
    case BLK_LEN_HI:   return "LEN_HI";
    case BLK_DATA:     return "DATA";
    case BLK_CHECKSUM: return "CHECKSUM";
  }
  return "?";
}

void resetBlockFsmOnly() {
  // Reset the block FSM but DO NOT touch blkFile -- it's pre-opened during
  // the leader and stays open across the whole reception.
  blkState  = BLK_MAGIC0;
  blkAddr   = 0;
  blkLength = 0;
  blkRemain = 0;
  blkXor    = 0;
  dataBufLen = 0;
  dataBufFlushPending = false;
  bytesReceivedRunning = 0;
}

void abortBlock(FailReason why) {
  // Snapshot the diagnostic state BEFORE we reset.
  bytesReceivedAtFail = bytesReceivedRunning;
  blockStateAtFail    = blkState;
  addrAtFail          = blkAddr;
  lengthAtFail        = blkLength;

  // Close and remove the staging file.  We do NOT touch PROG.BIN here so
  // that a failed save leaves the previous successful save intact and
  // loadable.  SD.remove() is a no-op when the file doesn't exist, so the
  // unconditional call is safe even if prepareFile() never ran.
  if (blkFile) blkFile.close();
  SD.remove((char *)TMP_FILENAME);
  resetBlockFsmOnly();
  result     = RES_ERROR;
  failReason = why;
}

// Pre-open a staging file (TEMP.BIN) so the received block can stream
// straight in.  Called from the leader-locked event in serviceListen, which
// fires while the rest of the leader is still playing -- several seconds of
// margin remain for the SD operations below.
//
// We write to TEMP.BIN rather than PROG.BIN directly so that an aborted or
// failed save never destroys the previous good PROG.BIN -- the user can still
// LOAD the last successful save even if the current one fails.  finalizeSave()
// does the atomic swap after the checksum is verified.
//
// CRITICAL: we pass O_WRITE|O_CREAT|O_TRUNC, NOT FILE_WRITE.  FILE_WRITE
// includes O_APPEND, which makes every write() seek to end-of-file first.
// With O_APPEND, seek(0) followed by write() would still write at the end,
// placing all received data after the pre-allocated zeros rather than
// overwriting them -- the file would be double MAX_DATA_LEN and LOAD would
// read all zeros.  O_WRITE|O_CREAT|O_TRUNC opens a plain writable file with
// no append behaviour, so seek(0) + write() works as expected.
void prepareFile() {
  if (blkFile) blkFile.close();
  SD.remove((char *)TMP_FILENAME);
  blkFile = SD.open(TMP_FILENAME, O_WRITE | O_CREAT | O_TRUNC);
  if (!blkFile) return;

  // No pre-allocation: TEMP.BIN starts empty, and the first write from
  // serviceListen() will trigger a FAT cluster allocation (~20–50 ms).
  // This is safe because serviceListen() runs AFTER serviceDecode() has
  // drained the ring, giving the ring its full 53 ms of headroom.
  //
  // Pre-allocating (writing zeros then seeking back to 0) was tried but
  // caused multi-second SD stalls: overwriting a sector already on flash
  // forces an erase-before-program cycle, which cheap SD cards can stall
  // on for seconds.  Fresh writes (no prior content) skip the erase and
  // complete in ~5 ms.  Cluster allocation at first write is slower
  // (~20–50 ms) but well within the 53 ms ring headroom.
}

bool writeSidecar(uint16_t addr, uint16_t length) {
  if (SD.exists((char *)TXT_FILENAME)) SD.remove((char *)TXT_FILENAME);
  File tx = SD.open(TXT_FILENAME, FILE_WRITE);
  if (!tx) return false;
  char hex[8];
  snprintf(hex, sizeof(hex), "0x%04X", addr);
  tx.print(F("addr="));
  tx.println(hex);
  snprintf(hex, sizeof(hex), "0x%04X", length);
  tx.print(F("len="));
  tx.println(hex);
  tx.close();
  return true;
}

// Copy exactly len bytes from TEMP.BIN (the pre-allocated staging file) to a
// fresh PROG.BIN, delete TEMP.BIN, and write the PROG.TXT sidecar.  Called
// after the checksum is verified, so SD timing is not a constraint.
// On success returns true and PROG.BIN has exactly len bytes.
// On failure returns false; any partial PROG.BIN is deleted.
bool finalizeSave(uint16_t addr, uint16_t len) {
  File src = SD.open(TMP_FILENAME, FILE_READ);
  if (!src) return false;

  SD.remove((char *)BIN_FILENAME);
  File dst = SD.open(BIN_FILENAME, O_WRITE | O_CREAT | O_TRUNC);
  if (!dst) { src.close(); return false; }

  uint16_t remaining = len;
  bool ok = true;
  while (remaining > 0) {
    uint16_t chunk = (remaining >= RAM_BUF_SIZE) ? RAM_BUF_SIZE : remaining;
    int n = src.read(dataBuf, chunk);
    if (n <= 0) { ok = false; break; }
    dst.write(dataBuf, (uint16_t)n);
    remaining -= (uint16_t)n;
  }
  src.close();
  dst.close();
  SD.remove((char *)TMP_FILENAME);

  if (!ok) { SD.remove((char *)BIN_FILENAME); return false; }
  return writeSidecar(addr, len);
}

bool sinkByte(uint8_t b) {
  // Count any byte that we actually accept as part of the block (matched
  // magic byte, address byte, length byte, data byte) -- but NOT a byte
  // that is going to cause us to abort.  We need to do this carefully so
  // a byte that fails validation does not get counted before abortBlock
  // captures the snapshot.
  switch (blkState) {
    case BLK_MAGIC0:
      if (b != MAGIC_0) { abortBlock(FAIL_MAGIC); return false; }
      bytesReceivedRunning++;
      blkState = BLK_MAGIC1;
      return true;

    case BLK_MAGIC1:
      if (b != MAGIC_1) { abortBlock(FAIL_MAGIC); return false; }
      bytesReceivedRunning++;
      blkState = BLK_ADDR_LO;
      return true;

    case BLK_ADDR_LO:
      blkAddr  = b;
      bytesReceivedRunning++;
      blkState = BLK_ADDR_HI;
      return true;

    case BLK_ADDR_HI:
      blkAddr |= (uint16_t)b << 8;
      bytesReceivedRunning++;
      blkState = BLK_LEN_LO;
      return true;

    case BLK_LEN_LO:
      blkLength = b;
      bytesReceivedRunning++;
      blkState  = BLK_LEN_HI;
      return true;

    case BLK_LEN_HI:
      blkLength |= (uint16_t)b << 8;
      if (blkLength == 0 || blkLength > MAX_DATA_LEN) {
        abortBlock(FAIL_LENGTH);
        return false;
      }
      // File is already open (pre-opened during the leader) -- just check.
      if (!blkFile) {
        abortBlock(FAIL_FILE);
        return false;
      }
      bytesReceivedRunning++;
      blkRemain = blkLength;
      blkXor    = 0;
      blkState  = BLK_DATA;
      return true;

    case BLK_DATA:
      // Buffer into RAM — never call blkFile.write() here.  See RAM_BUF_SIZE
      // comment above for the full explanation.
      dataBuf[dataBufLen++] = b;
      blkXor ^= b;
      bytesReceivedRunning++;
      blkRemain--;
      if (dataBufLen == RAM_BUF_SIZE) {
        // Signal serviceListen() to flush this chunk after serviceDecode()
        // returns.  We cannot flush here because we are inside the decoder
        // callback; doing SD I/O now would block the ring drain.
        dataBufFlushPending = true;
      }
      if (blkRemain == 0) blkState = BLK_CHECKSUM;
      return true;

    case BLK_CHECKSUM:
      if (b == blkXor) {
        // Flush whatever is left in dataBuf (may be the entire file for small
        // blocks, or the final partial sector for large ones).
        if (dataBufLen > 0) {
          blkFile.write(dataBuf, dataBufLen);
          dataBufLen = 0;
        }
        blkFile.flush();
        blkFile.close();
        // Copy exactly blkLength bytes from TEMP.BIN -> PROG.BIN and write
        // PROG.TXT.  PROG.BIN ends up the exact right size.
        if (finalizeSave(blkAddr, blkLength)) {
          result     = RES_SUCCESS;
          failReason = FAIL_NONE;
          resultAddr = blkAddr;
          resultLen  = blkLength;
        } else {
          result     = RES_ERROR;
          failReason = FAIL_FILE;
        }
        resetBlockFsmOnly();
      } else {
        abortBlock(FAIL_CHECKSUM);
      }
      // Either way: end of block.  Returning false resets the bit FSM
      // back to leader-hunt so we're ready for the next save.
      return false;
  }
  // Unreachable.
  abortBlock(FAIL_FRAME);
  return false;
}

void abortDuringDecode(Kcs::AbortReason why) {
  // Called by the Kcs decoder on framing error or mid-block silence timeout.
  // The decoder only invokes this once it's past the leader, so we always
  // treat it as a real failure.
  FailReason r;
  switch (why) {
    case Kcs::ABORT_TIMEOUT_AFTER_LEADER: r = FAIL_TIMEOUT_AFTER_LEADER; break;
    case Kcs::ABORT_TIMEOUT_MID_BYTE:     r = FAIL_TIMEOUT_MID_BYTE;     break;
    case Kcs::ABORT_FRAMING:              // fall through
    default:                              r = FAIL_FRAME;                break;
  }
  abortBlock(r);
}


// ============================================================================
// LOAD state
// ============================================================================

enum TxPhase : uint8_t {
  TX_IDLE,
  TX_SILENCE_HEAD,
  TX_LEADER,
  TX_HEADER,
  TX_DATA,
  TX_CHECKSUM,
  TX_SILENCE_TAIL,
};

TxPhase  txPhase = TX_IDLE;
File     txFile;
uint16_t txAddr  = 0;
uint16_t txLen   = 0;       // remaining bytes to send
uint8_t  txXor   = 0;

// Strip leading whitespace; return pointer past it.
const char *skipWs(const char *p) {
  while (*p == ' ' || *p == '\t') p++;
  return p;
}

// Trim trailing whitespace and CR in place.
void rtrim(char *s) {
  size_t n = strlen(s);
  while (n > 0 && (s[n - 1] == ' ' || s[n - 1] == '\t' ||
                   s[n - 1] == '\r' || s[n - 1] == '\n')) {
    s[--n] = 0;
  }
}

uint16_t parseUint16(const char *s) {
  s = skipWs(s);
  if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) return strtoul(s + 2, nullptr, 16);
  if (s[0] == '$')                                  return strtoul(s + 1, nullptr, 16);
  return strtoul(s, nullptr, 0);
}

bool readSidecar(uint16_t &addr, uint16_t &len) {
  addr = 0xFFFF;
  len  = 0;
  File f = SD.open(TXT_FILENAME);
  if (!f) return false;

  char line[40];
  while (f.available()) {
    int n = f.readBytesUntil('\n', line, sizeof(line) - 1);
    line[n] = 0;
    rtrim(line);
    char *eq = strchr(line, '=');
    if (!eq) continue;
    *eq = 0;
    char *key = line;
    char *val = eq + 1;
    rtrim(key);

    uint16_t parsed = parseUint16(val);
    if      (strcmp(key, "addr") == 0) addr = parsed;
    else if (strcmp(key, "len")  == 0) len  = parsed;
  }
  f.close();
  return len > 0 && len <= MAX_DATA_LEN;
}

}  // anonymous namespace


// ============================================================================
// Public API
// ============================================================================

void beginListening() {
  resetBlockFsmOnly();
  if (blkFile) blkFile.close();             // make sure no stale handle
  result     = RES_NONE;
  failReason = FAIL_NONE;
  Kcs::beginDecode(sinkByte, abortDuringDecode);
}

void serviceListen() {
  Kcs::serviceDecode();

  // If a full RAM_BUF_SIZE chunk was filled during the decode pass above,
  // flush it to SD now.  We are back in the main loop here — outside the
  // sinkByte callback — so the ring has its full ~53 ms of headroom before
  // it can overflow.  This keeps the SD write off the critical decoder path.
  if (dataBufFlushPending && blkFile) {
    dataBufFlushPending = false;
    blkFile.write(dataBuf, RAM_BUF_SIZE);
    // Preserve bytes that sinkByte() may have added past the RAM_BUF_SIZE
    // mark while dataBufFlushPending was set but serviceDecode() hadn't yet
    // returned.  At 300 baud at most 2-3 such bytes can arrive.
    uint16_t overflow = (dataBufLen > RAM_BUF_SIZE) ? (dataBufLen - RAM_BUF_SIZE) : 0;
    if (overflow) memmove(dataBuf, dataBuf + RAM_BUF_SIZE, overflow);
    dataBufLen = overflow;
  }

  // Pre-open PROG.BIN as soon as we lock the leader.  We have several
  // seconds of leader still to play out, so the SD operation finishes
  // well before the first data byte arrives.  Without this, the open
  // would happen between the LEN_HI byte and the first DATA byte (where
  // there are only ~3 ms of breathing room) and would corrupt reception.
  if (Kcs::consumeLeaderLockedEvent()) {
    prepareFile();
  }
}

Result      lastResult()         { return result;     }
FailReason  lastFailReason()     { return failReason; }
uint16_t    lastBytesReceived()  { return bytesReceivedAtFail; }
const char *lastBlockStateName() { return blockStateName(blockStateAtFail); }
uint16_t    lastDecodedAddr()    { return addrAtFail;   }
uint16_t    lastDecodedLength()  { return lengthAtFail; }
uint16_t    lastAddr()           { return resultAddr;   }
uint16_t    lastLength()         { return resultLen;    }

void clearResult() {
  result              = RES_NONE;
  failReason          = FAIL_NONE;
  resultAddr          = 0;
  resultLen           = 0;
  bytesReceivedAtFail = 0;
  blockStateAtFail    = BLK_MAGIC0;
  addrAtFail          = 0;
  lengthAtFail        = 0;
}

// ----------------------------------------------------------------------------

bool beginTransmit() {
  if (!SD.exists((char *)BIN_FILENAME)) return false;
  if (!SD.exists((char *)TXT_FILENAME)) return false;
  if (!readSidecar(txAddr, txLen))      return false;

  txFile = SD.open(BIN_FILENAME);
  if (!txFile) return false;

  if (txFile.size() < txLen) {
    txFile.close();
    return false;
  }

  Kcs::endDecode();
  Kcs::beginEncode();
  txXor   = 0;
  txPhase = TX_SILENCE_HEAD;
  return true;
}

bool serviceTransmit() {
  switch (txPhase) {
    case TX_SILENCE_HEAD:
      Kcs::emitSilenceMs(SILENCE_MS);
      txPhase = TX_LEADER;
      return false;

    case TX_LEADER:
      Kcs::emitMarkBits(LEADER_BITS);
      txPhase = TX_HEADER;
      return false;

    case TX_HEADER:
      Kcs::emitByte(MAGIC_0);
      Kcs::emitByte(MAGIC_1);
      Kcs::emitByte((uint8_t)(txAddr & 0xFF));
      Kcs::emitByte((uint8_t)(txAddr >> 8));
      Kcs::emitByte((uint8_t)(txLen  & 0xFF));
      Kcs::emitByte((uint8_t)(txLen  >> 8));
      txPhase = TX_DATA;
      return false;

    case TX_DATA: {
      // Stream the payload one byte at a time; the SD library buffers
      // internally, so reads stay cheap until we cross a sector boundary.
      while (txLen > 0) {
        int b = txFile.read();
        if (b < 0) {
          // Premature EOF -- shouldn't happen because we checked size().
          txFile.close();
          Kcs::endEncode();
          txPhase = TX_IDLE;
          return true;
        }
        Kcs::emitByte((uint8_t)b);
        txXor ^= (uint8_t)b;
        txLen--;
      }
      txPhase = TX_CHECKSUM;
      return false;
    }

    case TX_CHECKSUM:
      Kcs::emitByte(txXor);
      txPhase = TX_SILENCE_TAIL;
      return false;

    case TX_SILENCE_TAIL:
      Kcs::emitSilenceMs(SILENCE_MS);
      txFile.close();
      Kcs::endEncode();
      txPhase = TX_IDLE;
      return true;

    case TX_IDLE:
    default:
      return true;
  }
}

}  // namespace Session
