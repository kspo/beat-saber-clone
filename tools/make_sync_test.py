#!/usr/bin/env python3
"""Generate an original 120 BPM rhythm check; requires numpy and soundfile."""
import json
from pathlib import Path
import struct
import sys
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/audio-python'))
import numpy as np
import soundfile as sf

RATE = 48000
BPM = 120
DURATION = 64
DEST = ROOT / 'artifacts/SyncTest120'
DEST.mkdir(parents=True, exist_ok=True)
audio = np.zeros(RATE * DURATION, dtype=np.float32)

def add(start, signal):
    offset = round(start * RATE)
    length = min(len(signal), len(audio) - offset)
    audio[offset:offset + length] += signal[:length]

for beat in range(128):
    start = beat * 60 / BPM
    t = np.arange(round(RATE * .22), dtype=np.float32) / RATE
    attack = np.minimum(t / .001, 1)
    # Kick and a short, clear click share the exact chart timestamp.
    kick = .42 * np.sin(2*np.pi*(54*t + 6*(1-np.exp(-t*35)))) * np.exp(-t*24) * attack
    click_freq = 2200 if beat % 4 == 0 else 1600
    click = .26 * np.sin(2*np.pi*click_freq*t) * np.exp(-t*160) * attack
    add(start, kick + click)
    if beat >= 4:
        tone = [110, 98, 87.307, 98][((beat-4)//8) % 4]
        bass = .08 * np.sin(2*np.pi*tone*t) * np.exp(-t*18) * attack
        add(start, bass)
assert float(np.max(np.abs(audio))) < .95
sf.write(DEST / 'song.ogg', audio, RATE, format='OGG', subtype='VORBIS')

colors = {'_colorLeft': {'r': .9, 'g': .12, 'b': .2}, '_colorRight': {'r': .08, 'g': .48, 'b': 1.0}}
difficulties = []
for name, rank in [('Easy', 1), ('Normal', 3)]:
    filename = name + 'Standard.dat'
    notes = []
    for index, beat in enumerate(range(4, 124)):
        hand = index % 2
        direction = 8 if name == 'Easy' else (1 if (index // 2) % 2 == 0 else 0)
        notes.append({'_time': beat, '_lineIndex': 1 + hand, '_lineLayer': 1,
                      '_type': hand, '_cutDirection': direction})
    chart = {'_version': '2.0.0', '_notes': notes, '_obstacles': [], '_events': []}
    (DEST / filename).write_text(json.dumps(chart, separators=(',', ':')))
    difficulties.append({'_difficulty': name, '_difficultyRank': rank,
                         '_beatmapFilename': filename, '_noteJumpMovementSpeed': 10,
                         '_noteJumpStartBeatOffset': 0})
info = {'_version': '2.0.0', '_songName': 'SYNC TEST 120',
        '_songSubName': 'One block per beat - Easy first',
        '_songAuthorName': 'OpenSaberPlus Test', '_levelAuthorName': 'OpenSaberPlus Test',
        '_beatsPerMinute': BPM, '_songTimeOffset': 0, '_shuffle': 0, '_shufflePeriod': .5,
        '_previewStartTime': 2, '_previewDuration': 8, '_songFilename': 'song.ogg',
        '_coverImageFilename': 'cover.png', '_environmentName': 'DefaultEnvironment',
        '_customData': colors, '_difficultyBeatmapSets': [
            {'_beatmapCharacteristicName': 'Standard', '_difficultyBeatmaps': difficulties}]}
(DEST / 'Info.dat').write_text(json.dumps(info, indent=2))

# Simple original cover, no external artwork or fonts.
pixels = np.full((256, 256, 3), [8, 12, 24], dtype=np.uint8)
for x, color in [(32, [230, 31, 51]), (144, [20, 122, 255])]:
    pixels[72:168, x:x+80] = color
    yy, xx = np.ogrid[:256, :256]
    pixels[(xx-x-40)**2 + (yy-120)**2 < 12**2] = [255, 255, 255]
for x in range(24, 240, 32): pixels[204:212, x:x+12] = [150, 175, 200]
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
raw = b''.join(b'\0'+row.tobytes() for row in pixels)
(DEST/'cover.png').write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,256,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
(DEST/'README.txt').write_text('SYNC TEST 120: original synthesized test track. CC0.\n'
    '64 seconds, 120 BPM, 120 notes per chart. Four count-in beats; first note at 2.000 seconds.\n'
    'Use Easy, 100% speed, 0 ms offset, headset speakers. Every click after count-in matches one note.\n'
    'Judge arrival at the cutting position, not first appearance in the distance.\n'
    'Positive audio offset delays notes. Negative offset advances notes.\n'
    'A fixed offset cannot correct increasing drift.\n')
archive = ROOT/'artifacts/SyncTest120.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
    for file in sorted(DEST.iterdir()): out.write(file, file.name)
# Decode and check each scheduled click near its authored sample position.
decoded, rate = sf.read(DEST/'song.ogg', dtype='float32')
assert rate == RATE and len(decoded) == RATE * DURATION
for beat in range(128):
    i = round(beat * RATE / 2)
    assert float(np.max(np.abs(decoded[i:i+480]))) > .1
print(f'{archive}: {archive.stat().st_size} bytes; 128 audio pulses, 120 notes/chart verified.')
