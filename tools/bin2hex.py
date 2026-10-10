#!/usr/bin/env python3
"""Convert little-endian RV32 binary into one 32-bit word per $readmemh line."""
import pathlib
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: bin2hex.py input.bin output.hex")
data = pathlib.Path(sys.argv[1]).read_bytes()
if len(data) % 4:
    raise SystemExit("binary length must be a multiple of 4")
pathlib.Path(sys.argv[2]).write_text(
    "".join(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n"
            for i in range(0, len(data), 4)),
    encoding="ascii",
)
