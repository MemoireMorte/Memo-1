# bin2memo1.py

Converts a raw binary file into a WAV audio file that can be played back into the Memo-1 cassette input to load a program.

## Requirements

Python 3.7 or later. No third-party packages — only the standard library is used.

## Usage

```bash
python3 bin2memo1.py --bin <file> --start <addr> [--out <file>]
```

### Options

| Option    | Required | Description 
|-----------|----------|-------------
| `--bin`   | yes      | Input binary file 
| `--start` | yes      | Load address in hex, e.g. `6C00` or `0x6C00` 
| `--out`   | no       | Output WAV file (default: same name as input with `.wav` extension) 

### Examples

```bash
# Load at $6C00, output to code.wav
python3 bin2memo1.py --bin code.bin --start 6C00

# Explicit output name
python3 bin2memo1.py --bin code.bin --start 0x6C00 --out tape.wav
```

## What it produces

A mono, 44.1 kHz, 16-bit WAV file encoding a standard Memo-1 KCS block:

```
[0.5 s silence]
[leader]       ~5 seconds of 2400 Hz tone (lets the Memo-1 reader lock on)
[magic]        0x4D 0x31  ('M', '1' — Memo-1 block identifier)
[start addr]   2 bytes, little-endian
[length]       2 bytes, little-endian
[data]         the binary contents
[checksum]     1 byte, XOR of all data bytes
[0.5 s silence]
```

## How to load it on the Memo-1

1. Connect the audio output of your computer or phone to the Memo-1 cassette input.
2. Boot the Memo-1 and select **3 - Binary tape** from the main menu.
3. Choose **L - Load binary from tape**.
4. Start playback of the WAV file.
5. The Memo-1 will display `Loading...` and wait for the leader tone to lock on.
6. Once the block is received, it will show `Loaded.` along with the start address.
7. Choose **R - Run** to execute the loaded program, or **B** to return to the menu.

## KCS encoding details

The Memo-1 uses [Kansas City Standard](https://en.wikipedia.org/wiki/Kansas_City_standard) at 300 baud:

| Bit | Frequency | Cycles/bit | Half-periods/bit |
|-----|-----------|------------|------------------|
| 0   | 1200 Hz   | 4          | 8                |
| 1   | 2400 Hz   | 8          | 16               |

Each byte is framed as: **1 start bit (0)** + **8 data bits LSB first** + **2 stop bits (1, 1)**.

The signal is a square wave. The script uses a fractional sample accumulator so that the non-integer half-period lengths (e.g. 44100 / 2400 = 18.375 samples) are distributed correctly over time without cumulative drift.

## Notes

- The start address is the address where the binary will be loaded in RAM — it must be within `$0000–$7FFF` (RAM range).
- The start address does **not** have to be the entry point. After loading, the Memo-1 will ask for an entry address separately, defaulting to the start address.
- The script rejects binaries that would overflow past `$FFFF`.
