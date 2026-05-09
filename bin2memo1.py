#!/usr/bin/env python3
from __future__ import annotations
"""
bin2memo1.py — Convert a binary file to a Memo-1 KCS audio file.

The output WAV can be played back into the Memo-1 cassette input.

Usage:
    python3 bin2memo1.py --bin ./code.bin --start 6C00
    python3 bin2memo1.py --bin ./code.bin --start 0x6C00 --out tape.wav

KCS encoding (300 baud):
    Bit 0  →  1200 Hz square wave  (4 full cycles  = 8  half-periods per bit)
    Bit 1  →  2400 Hz square wave  (8 full cycles  = 16 half-periods per bit)

UART frame per byte:
    1 start bit (0) | D0 D1 D2 D3 D4 D5 D6 D7 (LSB first) | 2 stop bits (1 1)

Block layout on tape:
    [leader]     1500 × 1-bits  (~5 s of 2400 Hz, lets the reader lock on)
    [magic]      0x4D 0x31  ('M', '1' — Memo-1 identifier)
    [start addr] 2 bytes, little-endian
    [length]     2 bytes, little-endian
    [data]       <length> bytes
    [checksum]   1 byte, XOR of data bytes only (header not included)
"""

import argparse
import array
import os
import struct
import sys
import wave

# ---------------------------------------------------------------------------
# Audio constants
# ---------------------------------------------------------------------------

SAMPLE_RATE  = 44100        # Hz
AMPLITUDE    = 28000        # ~85 % of 16-bit max; leaves headroom for D/A chain
SILENCE_SECS = 0.5          # seconds of silence before and after the signal

# ---------------------------------------------------------------------------
# KCS constants (must match kcs.s)
# ---------------------------------------------------------------------------

LEADER_BITS = 1500          # 6 outer × 250 inner, see KCS_SEND_LEADER
MAGIC       = bytes([0x4D, 0x31])   # 'M', '1'


# ---------------------------------------------------------------------------
# Encoding helpers
# ---------------------------------------------------------------------------

def byte_to_frame(byte_val: int) -> list[int]:
    """Return the 11-bit KCS frame for one byte (start + 8 data LSB-first + 2 stop)."""
    bits = [0]                              # start bit
    for i in range(8):
        bits.append((byte_val >> i) & 1)   # data bits, LSB first
    bits += [1, 1]                         # stop bits
    return bits


def build_bits(data: bytes, start_addr: int) -> list[int]:
    """Build the complete bit stream for a Memo-1 KCS block."""
    bits: list[int] = []

    # Leader
    bits.extend([1] * LEADER_BITS)

    # Header (not included in checksum)
    checksum = 0
    for b in data:
        checksum ^= b

    stream = (
        MAGIC
        + struct.pack('<H', start_addr)
        + struct.pack('<H', len(data))
        + data
        + bytes([checksum])
    )

    for byte_val in stream:
        bits.extend(byte_to_frame(byte_val))

    return bits


def bits_to_samples(bits: list[int]) -> array.array:
    """
    Convert a KCS bit stream to 16-bit signed PCM samples.

    Uses a fractional accumulator so that non-integer half-period lengths
    (e.g. 44100 / 2400 = 18.375 samples) are spread correctly over time
    without cumulative drift.
    """
    samples: array.array = array.array('h')
    level = 1       # current polarity: +1 or -1
    frac  = 0.0     # carry-over fractional samples

    for bit in bits:
        if bit == 0:
            half_period = SAMPLE_RATE / 2400.0  # ~18.375 samples
            num_halves  = 8
        else:
            half_period = SAMPLE_RATE / 4800.0  # ~9.1875 samples
            num_halves  = 16

        for _ in range(num_halves):
            frac += half_period
            n     = int(frac)
            frac -= n
            samples.extend([level * AMPLITUDE] * n)
            level = -level

    return samples


def write_wav(path: str, samples: array.array) -> None:
    with wave.open(path, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)          # 16-bit
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(samples.tobytes())


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def parse_hex_addr(s: str) -> int:
    s = s.strip()
    try:
        return int(s, 16)           # accepts '6C00', '0x6C00', '6c00'
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"Invalid address '{s}' — expected hex, e.g. 6C00 or 0x6C00"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Convert a binary file to a Memo-1 KCS audio file (.wav).',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Example:\n  python3 bin2memo1.py --bin code.bin --start 6C00',
    )
    parser.add_argument('--bin',   required=True, metavar='FILE',
                        help='Input binary file')
    parser.add_argument('--start', required=True, metavar='ADDR', type=parse_hex_addr,
                        help='Load address in hex (e.g. 6C00 or 0x6C00)')
    parser.add_argument('--out',   metavar='FILE',
                        help='Output WAV file (default: <input>.wav)')
    args = parser.parse_args()

    # --- Validate input ---
    if not os.path.isfile(args.bin):
        print(f"Error: file not found: {args.bin}", file=sys.stderr)
        sys.exit(1)

    with open(args.bin, 'rb') as f:
        data = f.read()

    if len(data) == 0:
        print("Error: input file is empty", file=sys.stderr)
        sys.exit(1)

    if len(data) > 0xFFFF:
        print("Error: binary too large (max 65535 bytes)", file=sys.stderr)
        sys.exit(1)

    end_addr = args.start + len(data) - 1
    if end_addr > 0xFFFF:
        print(
            f"Error: block overflows address space "
            f"(start=${args.start:04X}, length={len(data)}, end=${end_addr:X})",
            file=sys.stderr,
        )
        sys.exit(1)

    out_path = args.out or (os.path.splitext(args.bin)[0] + '.wav')

    # --- Build audio ---
    print(f"Input:    {args.bin}")
    print(f"Start:    ${args.start:04X}")
    print(f"End:      ${end_addr:04X}")
    print(f"Length:   {len(data)} bytes")

    bits    = build_bits(data, args.start)
    signal  = bits_to_samples(bits)

    silence_len = int(SAMPLE_RATE * SILENCE_SECS)
    silence     = array.array('h', [0] * silence_len)

    all_samples: array.array = array.array('h')
    all_samples.extend(silence)
    all_samples.extend(signal)
    all_samples.extend(silence)

    duration = len(all_samples) / SAMPLE_RATE
    print(f"Output:   {out_path}  ({duration:.1f} s)")

    write_wav(out_path, all_samples)
    print("Done.")


if __name__ == '__main__':
    main()
