# Memo-1 KCS tools

Two companion scripts for transferring programs to and from the Memo-1 via
cassette audio using the
[Kansas City Standard](https://en.wikipedia.org/wiki/Kansas_City_standard):

| Script          | Direction          | Description                                  |
|-----------------|--------------------|----------------------------------------------|
| `bin2memo1.py`  | binary → WAV       | Encode a binary file as a KCS audio file     |
| `memo12bin.py`  | WAV → binary       | Decode a KCS audio file back to binary       |

## Requirements

Python 3.9 or later. No third-party packages — standard library only.

---

## bin2memo1.py — binary to WAV

Converts a raw binary file into a WAV audio file that can be played back into
the Memo-1 cassette input.

### Usage

```bash
python3 bin2memo1.py --bin <file> --start <addr> [--out <file>]
```

### Options

| Option    | Required | Description                                                          |
|-----------|----------|----------------------------------------------------------------------|
| `--bin`   | yes      | Input binary file                                                    |
| `--start` | yes      | Load address in hex, e.g. `6C00` or `0x6C00`                        |
| `--out`   | no       | Output WAV file (default: same stem as input with `.wav` extension)  |

### Examples

```bash
# Load at $6C00, output to code.wav
python3 bin2memo1.py --bin code.bin --start 6C00

# Explicit output name
python3 bin2memo1.py --bin code.bin --start 0x6C00 --out tape.wav
```

### What it produces

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

The signal is a square wave generated with a fractional sample accumulator so
that non-integer half-period lengths (e.g. 44100 / 2400 = 18.375 samples) are
distributed correctly over time without cumulative drift.

### Notes

- The start address is where the binary will be loaded in RAM
  (`$0000–$7FFF`).
- It does **not** have to be the entry point. After loading, the Memo-1 asks
  for an entry address separately, defaulting to the start address.
- The script rejects binaries that would overflow past `$FFFF`.

---

## memo12bin.py — WAV to binary

Decodes a Memo-1 KCS audio file back to a raw binary.

### Usage

```bash
python3 memo12bin.py <file.wav> [--out <file>]
```

### Options

| Option  | Required | Description                                                                    |
|---------|----------|--------------------------------------------------------------------------------|
| `wav`   | yes      | Input KCS WAV file                                                             |
| `--out` | no       | Output binary file (default: `<stem>_<ADDR>.bin`, e.g. `tape_6C00.bin`)       |

### Examples

```bash
# Decode tape.wav; output goes to tape_6C00.bin (address read from block header)
python3 memo12bin.py tape.wav

# Explicit output name
python3 memo12bin.py tape.wav --out code.bin
```

### What it produces

A raw binary file containing exactly the data bytes from the KCS block.
The load address is embedded in the default output filename and printed to
stdout:

```
Input:    tape.wav
Format:   44100 Hz, 396900 samples (9.0 s)
Start:    $6C00
End:      $6FFF
Length:   1024 bytes
Output:   tape_6C00.bin
Done.
```

The script exits with code 1 if no valid Memo-1 block is found or if the
checksum does not match.

### Decoding pipeline

```
WAV
 └─ load to mono signed samples
      └─ remove DC offset
           └─ zero-crossing detection  (with hysteresis)
                └─ classify half-periods  SHORT (2400 Hz) / LONG (1200 Hz)
                     └─ run-length decode to bit stream
                          └─ locate leader → decode block → verify checksum
```

Two measures protect against noise in real recordings:

- **Noise gate** — half-periods shorter than 40 % of the ideal 2400 Hz
  half-period are discarded.
- **Hysteresis** — zero crossings are only counted when the signal has
  exceeded 5 % of the peak amplitude, preventing jitter near baseline from
  generating spurious crossings.

---

## How to load a program on the Memo-1

1. Connect the audio output of your computer or phone to the Memo-1 cassette
   input.
2. Boot the Memo-1 and select **3 - Binary tape** from the main menu.
3. Choose **L - Load binary from tape**.
4. Start playback of the WAV file.
5. The Memo-1 will display `Loading...` and wait for the leader tone to lock
   on.
6. Once the block is received it will show `Loaded.` along with the start
   address.
7. Choose **R - Run** to execute the loaded program, or **B** to return to the
   menu.

---

## KCS encoding reference

The Memo-1 uses KCS at 300 baud:

| Bit | Frequency | Cycles/bit | Half-periods/bit |
|-----|-----------|------------|------------------|
| 0   | 1200 Hz   | 4          | 8                |
| 1   | 2400 Hz   | 8          | 16               |

Each byte is framed as **1 start bit (0)** + **8 data bits LSB first** +
**2 stop bits (1, 1)**.

Block layout:

```
[leader]     1500 × bit-1  (≈ 5 s of 2400 Hz)
[magic]      0x4D 0x31     ('M', '1')
[start addr] 2 bytes, little-endian
[length]     2 bytes, little-endian
[data]       <length> bytes
[checksum]   1 byte, XOR of data bytes only  (header excluded)
```
