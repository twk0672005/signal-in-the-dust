"""Original deterministic, tileable geological maps. No downloaded or AI assets."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / 'godot/assets/terrain'
OUT.mkdir(parents=True, exist_ok=True)
N = 1024
rng = np.random.default_rng(150926)
y, x = np.mgrid[:N, :N].astype(float) / N

def noise():
    a = np.zeros((N, N))
    fy,fx=np.meshgrid(np.fft.fftfreq(N),np.fft.fftfreq(N),indexing='ij')
    for frequency, weight in [(2, .06), (5, .055), (13, .035), (37, .02), (91, .009)]:
        filt=np.exp(-(fx*fx+fy*fy)*N*N/(frequency*frequency))
        layer=np.fft.ifft2(np.fft.fft2(rng.normal(0,1,(N,N)))*filt).real
        a+=layer/(layer.std()+1e-9)*weight
    return a

macro = noise()
fine = rng.normal(0, .019, (N,N))
strata = np.sin(2*np.pi*(y*46+x*6)+macro*24)
height = macro*.8 + strata*.003 + fine*.5
cracks = np.clip((np.abs(np.sin(2*np.pi*(x*3-y*2)+macro*18))-.945)*15,0,1)
height -= cracks*.07
rough = np.clip(.84+macro*.4+fine*2-cracks*.07,.63,.98)
tone = np.clip(.5+macro*1.8+fine*1.5-cracks*.2,0,1)
basalt = np.stack([.21+tone*.18,.19+tone*.14,.18+tone*.125],axis=2)
sand = np.stack([.43+tone*.23,.295+tone*.19,.205+tone*.135],axis=2)
dy, dx = np.gradient(height)
normal = np.stack([-dx*9,-dy*9,np.ones_like(dx)],axis=2)
normal /= np.linalg.norm(normal,axis=2)[...,None]
mask=np.ones((N,N,4))
mask[...,3]=np.exp(-((x-.5)**2+(y-.5)**2)*25)*np.clip(1-np.sqrt((x-.5)**2+(y-.5)**2)*2,0,1)
maps = {'basalt_albedo':basalt,'dust_albedo':sand,'geology_normal':normal*.5+.5,'geology_roughness':rough,'dust_mask':mask}
manifest = {'generator':'tools/create_terrain.py','seed':150926,'license':'Original project-authored procedural maps; CC0-1.0','resolution':[N,N],'files':{}}
for name, values in maps.items():
    target=OUT/(name+'.png')
    Image.fromarray((np.clip(values,0,1)*255).astype('uint8')).save(target)
    manifest['files'][target.name]={'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size}
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
print(json.dumps(manifest))
