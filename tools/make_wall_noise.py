#!/usr/bin/env python3
"""Bake an original periodic scalar field for obstacle contour lines (stdlib only)."""
from pathlib import Path
import math
import random
import struct
import zlib

SIZE = 256
rng = random.Random(8317)
modes = [(x, y, rng.uniform(0, math.tau), 1 / math.hypot(x, y))
         for x, y in [(1, 2), (2, -1), (3, 2), (2, 5), (7, -3), (5, 9), (13, 7), (19, -11)]]
normalization = sum(mode[3] for mode in modes)
raw = bytearray()
for y in range(SIZE):
    raw.append(0)  # PNG scanline filter
    for x in range(SIZE):
        value = sum(weight * math.sin(math.tau * (fx*x + fy*y) / SIZE + phase)
                    for fx, fy, phase, weight in modes) / normalization
        raw.append(round(127.5 + 127.5 * value))

def chunk(tag, payload):
    return struct.pack('>I', len(payload)) + tag + payload + struct.pack('>I', zlib.crc32(tag + payload))

png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 0, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
dest = Path(__file__).resolve().parents[1] / 'game/Wall/fracture_field.png'
dest.write_bytes(png)
print(dest, len(png), 'bytes')
