"""Reproducible original expedition sounds, rendered offline as mono PCM WAV.

No recordings, external samples, generative service, or runtime synthesis.
Seed 70117. Samples are original project assets; use under the project's licence.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/audio'
RATE = 22050
RNG = np.random.default_rng(70117)
OUT.mkdir(parents=True, exist_ok=True)
manifest = []

def time(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE

def periodic_noise(seconds, cutoff, low=25):
    """FFT-shaped noise is periodic by construction, including its derivatives."""
    count = round(seconds * RATE)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = RNG.normal(size=len(frequencies)) + 1j * RNG.normal(size=len(frequencies))
    shape = (1 - np.exp(-(frequencies / low) ** 4)) * np.exp(-(frequencies / cutoff) ** 2)
    result = np.fft.irfft(spectrum * shape, n=count)
    return result / max(np.max(np.abs(result)), 1e-9)

def save(name, data, loop=False):
    peak = float(np.max(np.abs(data)))
    data = data * min(1.0, 0.78 / max(peak, 1e-9))
    if not loop:
        fade = min(round(0.04 * RATE), len(data) // 4)
        data[:fade] *= np.linspace(0, 1, fade)
        data[-fade:] *= np.linspace(1, 0, fade)
    pcm = np.round(data * 32767).astype('<i2')
    path = OUT / f'{name}.wav'
    with wave.open(str(path), 'wb') as stream:
        stream.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        stream.writeframes(pcm.tobytes())
    manifest.append({'name': path.name, 'seconds': len(data)/RATE, 'bytes': path.stat().st_size,
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'peak': float(np.max(np.abs(data))), 'rms': float(np.sqrt(np.mean(data*data))),
                     'loop': loop, 'loop_boundary_delta': float(abs(data[-1]-data[0])) if loop else None})

t = time(10)
wind = periodic_noise(10, 630) * (.56 + .13*np.sin(2*np.pi*t/10) + .07*np.sin(2*np.pi*t*3/10))
wind += periodic_noise(10, 2800, 550) * .085
save('wind', wind * .7, True)
t = time(4)
rolling = periodic_noise(4, 260) * (.33 + .09*np.cos(2*np.pi*3*t))
rolling += .04*np.sin(2*np.pi*63*t) + .022*np.sin(2*np.pi*126*t)
save('rolling', rolling, True)
t = time(3)
servo = .14*np.sin(2*np.pi*174*t + .16*np.sin(2*np.pi*t)) + .045*np.sin(2*np.pi*348*t)
servo *= .7 + .2*np.sin(2*np.pi*t/3)
save('servo', servo, True)
t = time(4)
envelope = ((1-np.cos(2*np.pi*t/4))/2)**8
pulse = envelope * (.33*np.sin(2*np.pi*176*t) + .11*np.sin(2*np.pi*264*t) + .065*np.sin(2*np.pi*440*t))
save('pulse', pulse, True)
t = time(3)
envelope = (1-np.exp(-t*15))*np.exp(-t*1.55)
transmit = envelope*(.5*np.sin(2*np.pi*(350*t+45*t*t)) + .13*np.sin(2*np.pi*700*t))
save('transmit', transmit)
t = time(13)
response = np.zeros_like(t)
for idx, frequency in enumerate([110, 165, 220, 277.18, 330, 440]):
    local_t = np.maximum(t-idx*.42, 0)
    envelope = (1-np.exp(-local_t*1.8))*np.exp(-local_t*.27)
    response += envelope*np.sin(2*np.pi*frequency*local_t + .12*np.sin(2*np.pi*.17*local_t))*.15
response += periodic_noise(13, 750)*np.sin(np.pi*t/13)**2*.04
save('response', response)
total = sum(item['bytes'] for item in manifest)
assert total <= 4*1024*1024, total
(OUT/'PROVENANCE.json').write_text(json.dumps({'author':'Original project synthesis', 'generator':'tools/create_audio.py',
 'seed':70117,'sample_rate':RATE,'channels':1,'encoding':'PCM signed 16-bit','total_bytes':total,'assets':manifest}, indent=2)+'\n')
print(json.dumps({'total_bytes':total,'samples':len(manifest),'peak':max(item['peak'] for item in manifest)}))
