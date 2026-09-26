"""Original short, non-looping UI acknowledgement; no external sound source."""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave

root = Path(__file__).resolve().parents[1]
target = root / 'godot/assets/audio/whisper.wav'
rate = 24000
duration = .22
samples = []
for index in range(round(rate * duration)):
    t = index / rate
    envelope = (1 - math.exp(-t * 130)) * math.exp(-t * 20) * min(1, (duration - t) / .025)
    tone = math.sin(math.tau * 740 * t) + .3 * math.sin(math.tau * 1110 * t)
    samples.append(round(32767 * .18 * envelope * tone))
with wave.open(str(target), 'wb') as sound:
    sound.setnchannels(1)
    sound.setsampwidth(2)
    sound.setframerate(rate)
    sound.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
record = {'source': 'Original local synthesized UI chime', 'tool': 'tools/create-whisper-chime.py',
          'duration_seconds': duration, 'sample_rate': rate, 'channels': 1, 'loop': False,
          'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
target.with_suffix('.provenance.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record))
