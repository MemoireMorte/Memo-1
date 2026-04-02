#!/usr/bin/env python3
from __future__ import annotations
"""
memo12bin.py — Convert a Memo-1 KCS audio file (.wav) back to binary.

The inverse of bin2memo1.py.

Usage:
    python3 memo12bin.py tape.wav
    python3 memo12bin.py tape.wav --out code.bin

KCS encoding (300 baud):
    Bit 0  →  1200 Hz square wave  (8  half-periods per bit)
    Bit 1  →  2400 Hz square wave  (16 half-periods per bit)

UART frame per byte:
    1 start bit (0) | D0 D1 D2 D3 D4 D5 D6 D7 (LSB first) | 2 stop bits (1 1)

Block layout on tape:
    [leader]     long sequence of 1-bits (2400 Hz, ~5 s)
    [magic]      0x4D 0x31  ('M', '1' — Memo-1 identifier)
    [start addr] 2 bytes, little-endian
    [length]     2 bytes, little-endian
    [data]       <length> bytes
    [checksum]   1 byte, XOR of data bytes only (header not included)
"""

import argparse
import array
import os
import sys
import wave

MAGIC_0       = 0x4D    # 'M'
MAGIC_1       = 0x31    # '1'
LEADER_MIN    = 100     # minimum consecutive 1-bits to recognise as a valid leader


# ---------------------------------------------------------------------------
# Audio loading
# ---------------------------------------------------------------------------

def load_wav_mono(path: str) -> tuple[list[int], int]:
    """Load a WAV file and return (samples, sample_rate) as mono 16-bit."""
    with wave.open(path, 'r') as wf:
        n_channels = wf.getnchannels()
        sampwidth  = wf.getsampwidth()
        framerate  = wf.getframerate()
        raw        = wf.readframes(wf.getnframes())

    if sampwidth == 1:                      # 8-bit WAV is unsigned
        buf = array.array('B', raw)
        samples = [(s - 128) * 256 for s in buf]
    elif sampwidth == 2:                    # 16-bit signed
        buf = array.array('h')
        buf.frombytes(raw)
        samples = list(buf)
    elif sampwidth == 4:                    # 32-bit signed; scale to 16-bit range
        buf = array.array('i')
        buf.frombytes(raw)
        samples = [s >> 16 for s in buf]
    else:
        raise ValueError(f"Unsupported sample width: {sampwidth} bytes")

    # Downmix to mono by keeping left/only channel
    if n_channels > 1:
        samples = samples[::n_channels]

    return samples, framerate


def remove_dc_offset(samples: list[int]) -> list[int]:
    """Subtract the mean to eliminate any DC bias."""
    if not samples:
        return samples
    mean = sum(samples) // len(samples)
    return [s - mean for s in samples]


# ---------------------------------------------------------------------------
# Zero-crossing detection
# ---------------------------------------------------------------------------

def find_zero_crossings(samples: list[int], hysteresis: int = 0) -> list[int]:
    """
    Return sample indices where the signal changes sign.
    hysteresis: the signal must reach ±hysteresis before a crossing is counted,
    rejecting noise spikes near zero.
    """
    crossings = []
    state = 1 if samples[0] >= 0 else -1
    for i in range(1, len(samples)):
        s = samples[i]
        if state == -1 and s > hysteresis:
            crossings.append(i)
            state = 1
        elif state == 1 and s < -hysteresis:
            crossings.append(i)
            state = -1
    return crossings


# ---------------------------------------------------------------------------
# Half-period classification
# ---------------------------------------------------------------------------

def crossings_to_halves(crossings: list[int], framerate: int) -> list[int]:
    """
    Classify each interval between consecutive zero crossings as:
        1  →  SHORT (2400 Hz half-period, used by 1-bits)
        0  →  LONG  (1200 Hz half-period, used by 0-bits)

    The threshold sits at the midpoint between the two ideal half-period
    lengths.  Intervals shorter than 40 % of the ideal short half-period
    are discarded as noise spikes.
    """
    short_hp  = framerate / 4800.0           # ideal: SR/4800 samples (~9.19 @ 44100)
    long_hp   = framerate / 2400.0           # ideal: SR/2400 samples (~18.375 @ 44100)
    threshold = (short_hp + long_hp) / 2.0  # midpoint (~13.78 @ 44100)
    min_gate  = short_hp * 0.4              # noise floor gate

    halves = []
    for i in range(1, len(crossings)):
        d = crossings[i] - crossings[i - 1]
        if d < min_gate:
            continue                        # discard noise spike
        halves.append(1 if d < threshold else 0)

    return halves


# ---------------------------------------------------------------------------
# Half-period stream → bit stream
# ---------------------------------------------------------------------------

def halves_to_bits(halves: list[int]) -> list[int]:
    """
    Decode a half-period stream to a bit stream by run-length grouping.

        16 consecutive SHORT half-periods  →  one 1-bit
         8 consecutive LONG  half-periods  →  one 0-bit

    Counts are rounded to the nearest whole bit so small noise-induced
    miscounts are absorbed.
    """
    bits = []
    i = 0
    n = len(halves)
    while i < n:
        v = halves[i]
        j = i
        while j < n and halves[j] == v:
            j += 1
        count = j - i
        nbits = round(count / 16) if v == 1 else round(count / 8)
        bits.extend([v] * max(0, nbits))
        i = j
    return bits


# ---------------------------------------------------------------------------
# UART frame decoding
# ---------------------------------------------------------------------------

def read_byte(bits: list[int], pos: int) -> tuple[int | None, int]:
    """
    Read one 11-bit UART frame from bits[pos]:
        bits[pos]      = start bit (must be 0)
        bits[pos+1..8] = data bits D0–D7 (LSB first)
        bits[pos+9..10]= stop bits (must both be 1)

    Returns (byte_value, next_pos) on success, or (None, pos) on error.
    """
    if pos + 11 > len(bits):
        return None, pos
    if bits[pos] != 0:                      # start bit
        return None, pos
    if bits[pos + 9] != 1 or bits[pos + 10] != 1:   # stop bits
        return None, pos

    byte_val = 0
    for k in range(8):
        byte_val |= bits[pos + 1 + k] << k

    return byte_val, pos + 11


# ---------------------------------------------------------------------------
# Block decoding
# ---------------------------------------------------------------------------

def try_decode_block(bits: list[int], pos: int) -> tuple[bytes | None, int | None]:
    """
    Attempt to decode a full Memo-1 block starting at pos in the bit stream.

    Returns (data, start_addr) on success, or (None, None) on any error.
    """
    # Magic
    b, pos = read_byte(bits, pos)
    if b != MAGIC_0:
        return None, None
    b, pos = read_byte(bits, pos)
    if b != MAGIC_1:
        return None, None

    # Start address (little-endian)
    lo, pos = read_byte(bits, pos)
    if lo is None:
        return None, None
    hi, pos = read_byte(bits, pos)
    if hi is None:
        return None, None
    start_addr = lo | (hi << 8)

    # Length (little-endian)
    lo, pos = read_byte(bits, pos)
    if lo is None:
        return None, None
    hi, pos = read_byte(bits, pos)
    if hi is None:
        return None, None
    length = lo | (hi << 8)

    if length == 0 or length > 0x8000:
        return None, None

    # Data + running XOR checksum
    data     = bytearray()
    checksum = 0
    for _ in range(length):
        b, pos = read_byte(bits, pos)
        if b is None:
            return None, None
        data.append(b)
        checksum ^= b

    # Checksum byte
    stored_cs, pos = read_byte(bits, pos)
    if stored_cs is None:
        return None, None
    if stored_cs != checksum:
        print(f"  Checksum mismatch (computed {checksum:#04x}, stored {stored_cs:#04x})",
              file=sys.stderr)
        return None, None

    return bytes(data), start_addr


def find_block(bits: list[int]) -> tuple[bytes | None, int | None]:
    """
    Scan the bit stream for a valid Memo-1 block.
    Returns (data, start_addr) or (None, None).
    """
    n = len(bits)
    i = 0
    while i < n:
        # Skip non-leader bits
        if bits[i] != 1:
            i += 1
            continue

        # Measure leader length
        leader_start = i
        while i < n and bits[i] == 1:
            i += 1
        leader_len = i - leader_start

        if leader_len < LEADER_MIN:
            continue

        # Try to decode immediately after the leader
        data, start_addr = try_decode_block(bits, i)
        if data is not None:
            return data, start_addr

    return None, None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description='Decode a Memo-1 KCS audio file (.wav) to binary.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Example:\n  python3 memo12bin.py tape.wav\n  python3 memo12bin.py tape.wav --out code.bin',
    )
    parser.add_argument('wav',   metavar='FILE', help='Input KCS WAV file')
    parser.add_argument('--out', metavar='FILE', help='Output binary file (default: <input>.bin)')
    args = parser.parse_args()

    if not os.path.isfile(args.wav):
        print(f"Error: file not found: {args.wav}", file=sys.stderr)
        sys.exit(1)

    print(f"Input:    {args.wav}")

    samples, framerate = load_wav_mono(args.wav)
    print(f"Format:   {framerate} Hz, {len(samples)} samples ({len(samples) / framerate:.1f} s)")

    samples = remove_dc_offset(samples)

    # Hysteresis = 5 % of peak; rejects low-level noise without clipping real signal
    peak       = max(abs(s) for s in samples) if samples else 1
    hysteresis = int(peak * 0.05)

    crossings = find_zero_crossings(samples, hysteresis)
    halves    = crossings_to_halves(crossings, framerate)
    bits      = halves_to_bits(halves)

    data, start_addr = find_block(bits)

    if data is None:
        print("Error: no valid Memo-1 block found in the audio.", file=sys.stderr)
        sys.exit(1)

    end_addr = start_addr + len(data) - 1
    print(f"Start:    ${start_addr:04X}")
    print(f"End:      ${end_addr:04X}")
    print(f"Length:   {len(data)} bytes")

    out_path = args.out or (os.path.splitext(args.wav)[0] + f'_{start_addr:04X}.bin')
    with open(out_path, 'wb') as f:
        f.write(data)
    print(f"Output:   {out_path}")
    print("Done.")


if __name__ == '__main__':
    main()
