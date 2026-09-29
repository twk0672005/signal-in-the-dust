"""Original anatomy-directed surface maps. Python + NumPy + Pillow; no downloads.

Aeral uses authored (span s, chord t) UVs from FormV7, glTF V=1-t.
Scute UVs are (azimuth, apex-to-lip radius), also glTF V=1-radius.
Missing Morrow/shore-flier membrane UVs are added without changing geometry.
Run with --backup-dir pointing to this run's exact pre-edit GLBs.
"""
import argparse, hashlib, json, math, os, struct
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/visual_fauna/surface_maps'
N=512
v,u=np.mgrid[0:N,0:N].astype(np.float64)/(N-1)
t=1-v

def smooth(a,b,x):
    q=np.clip((x-a)/(b-a),0,1);return q*q*(3-2*q)

def save(name,pigment,rough,edge,height,depth):
    # Linear packed data: pigment, roughness, worn/vascular edge, thickness.
    data=np.stack([pigment,rough,edge,np.clip(height,0,1)],-1)
    assert np.isfinite(data).all(), f'{name}: non-finite surface data'
    dy,dx=np.gradient(height)
    normal=np.stack([-dx*N*depth,dy*N*depth,np.ones_like(dx)],-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    for suffix,array in [('structure',data),('normal',normal*.5+.5)]:
        path=OUT/f'{name}_{suffix}.png'
        temp=path.with_suffix('.tmp.png')
        Image.fromarray(np.uint8(np.clip(array,0,1)*255)).save(temp)
        os.replace(temp,path)

def maps():
    OUT.mkdir(exist_ok=True)
    # Growth follows the actual polar scute chart; erosion is concentrated
    # at the exposed lip and radial micro-cracks, not random whole-body spots.
    radial=t
    # Unequal accretion fronts merge in broad polished areas. Quiet anatomy is
    # the dominant surface; growth lines survive only in sheltered sectors.
    phase=radial*7.3+.27*np.sin(u*2*np.pi*3+radial*4)+.16*np.sin(radial*13)
    rings=.5+.5*np.sin(2*np.pi*phase)
    fused=smooth(-.35,.65,np.cos(u*2*np.pi*2+.9)+.5*np.sin(radial*9+u*2*np.pi))
    growth=smooth(.64,.94,rings)*smooth(.25,.62,radial)*(1-fused*.83)
    growth*=1-smooth(.90,.985,radial)
    lip=smooth(.92,.985,radial)
    cracks=np.exp(-(np.sin(2*np.pi*(u*7+.075*np.sin(radial*9)))/.075)**2)*smooth(.62,.96,radial)
    cracks*=smooth(.10,.65,np.sin(u*2*np.pi*3+1.2)+.2*np.cos(radial*6))
    cracks*=1-smooth(.88,.97,radial) # The side-wall UV collapses at the lip; no stretched cracks there.
    fine=.5+.5*np.sin(u*2*np.pi*83+np.sin(radial*38))*np.sin(radial*2*np.pi*71)
    broad=(.06*np.sin(u*2*np.pi*2+radial*5)+.035*np.cos(u*2*np.pi*5-radial*3))*(1-lip)
    root=1-smooth(.04,.23,radial)
    pigment=.75+broad-.25*growth-.23*cracks-.11*smooth(.68,.93,radial)+.14*lip-.09*root+.015*(fine-.5)*(1-lip)
    assert np.ptp(pigment[0]) < 1e-5, 'Collapsed lip UV must not turn surface marks into side-wall stripes.'
    assert np.mean(growth<.035)>.55, 'Most armour must remain quiet, not ring-covered.'
    height=.47+.105*growth-.075*cracks+.075*lip+.065*root+.003*(fine-.5)*(1-lip)
    wear=lip*.52+fused*smooth(.65,.88,radial)*(1-lip)*.25
    assert np.percentile(growth,95)>.4, 'Localized growth rims must retain readable relief.'
    save('scute',pigment,.60+.24*growth-.19*wear,wear*(1-cracks),height,.065)

    # Main vein curves coincide with the eight authored load-bearing fingers:
    # s=end-.09*(1-t). Smaller branches span those structural bays.
    veins=np.zeros_like(u); capillary=np.zeros_like(u)
    for k,end in enumerate([.16,.28,.40,.52,.64,.76,.88,.96]):
        center=end-.09*(1-t)
        veins=np.maximum(veins,np.exp(-((u-center)/(.0025+.002*(1-t)))**2))
        for j in range(1,8):
            attach=j/9+.034*math.sin(k*1.7+j*2.1)
            for side in [-1,1]:
                d=side*(u-center)
                branch_t=attach+d*1.4+.35*d*d
                mask=smooth(0,.009,d)*(1-smooth(.042,.059,d))
                line=np.exp(-((t-branch_t)/.0028)**2)*mask
                # Missing minor branches leave calm translucent tissue bays.
                if (j+2*k)%5: capillary=np.maximum(capillary,line*(.6+.3*math.sin(k+j)**2))
    edge=np.maximum(1-smooth(.015,.06,t),smooth(.955,.995,t))
    bays=.5+.5*np.sin(2*np.pi*(u*8+.09*(1-t)))
    fiber=.5+.5*np.sin(2*np.pi*(t*70+u*3))
    healed=np.exp(-((u-.74)/.085)**2-((t-.69)/.14)**2)
    maturity=.5+.5*np.sin(u*11+t*4)*np.cos(t*7-u*3)
    thickness=.19+.55*veins+.13*capillary+.24*edge+.15*healed
    pigment=.76+.075*bays-.26*veins-.11*capillary-.10*edge-.08*healed+.055*(maturity-.5)+.01*(fiber-.5)
    save('fan',pigment,.50+.18*veins+.13*capillary,capillary*.32+edge*.4,thickness,.010)

    # Morrow fronds and small flier wings: a central rachis with swept gills.
    x=(u-.5)*2
    mid=np.exp(-(x/.025)**2)
    branch_phase=(t-.28*np.abs(x)-.08*x*x)*11+.13*np.sin(t*14+x*5)
    branch=np.exp(-(np.sin(branch_phase*np.pi)/.16)**2)*smooth(.025,.10,np.abs(x))
    branch*=.3+.7*smooth(-.2,.6,np.sin(t*13+x*7))
    rim=smooth(.82,.99,np.abs(x))
    height=.25+.42*mid+.10*branch+.12*rim
    save('frond',.76-.25*mid-.14*branch-.10*rim,.58+.15*branch,mid*.25+branch*.12,height,.012)

    # Fine overlapping dermal scales, deliberately lower contrast than armor.
    flow_u=u+.018*np.sin(v*17)+.009*np.cos(u*13+v*8)
    flow_v=v+.015*np.sin(u*15)+.008*np.cos(v*9)
    row=np.floor(flow_v*24); xcell=np.mod(flow_u*28+.5*np.mod(row,2),1)-.5
    ycell=np.mod(flow_v*24,1)
    seam=np.exp(-((ycell-(.24+.68*np.sqrt(np.maximum(0,1-(xcell*2)**2))))/.07)**2)
    folds=.5+.5*np.sin(u*10+v*4)*np.cos(v*12-u*3)
    seam*=.28+.67*smooth(.35,.8,folds)
    # Broad unequal folds remain visible after mip filtering; only sheltered
    # patches retain the small scale boundaries, avoiding a tiled whole-body grid.
    crease=np.exp(-((v-(.32+.075*np.sin(u*8)))/.028)**2)
    crease+=.65*np.exp(-((v-(.72+.055*np.sin(u*11+.8)))/.038)**2)
    crease*=smooth(-.1,.7,np.sin(u*2*np.pi*2+.5))
    save('dermis',.73-.20*seam-.13*crease+.075*(folds-.5),.65+.12*seam+.07*crease,np.zeros_like(u),.45-.065*seam-.10*crease,.020)

def read_glb(path):
    b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0]
    return json.loads(b[20:20+n]),bytearray(b[28+n:])

def array(j,b,index):
    a=j['accessors'][index];view=j['bufferViews'][a['bufferView']]
    k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
    width=np.dtype(dtype).itemsize
    return np.ndarray((a['count'],k),dtype=dtype,buffer=b,offset=view.get('byteOffset',0)+a.get('byteOffset',0),strides=(view.get('byteStride',k*width),width)).copy()

def add_uv(path,backup):
    j,b=read_glb(backup/path.name); changes=[]
    for mesh in j['meshes']:
        for primitive in mesh['primitives']:
            label=j['materials'][primitive['material']]['name']
            attrs=primitive['attributes']
            if 'membrane' not in label or 'TEXCOORD_0' in attrs: continue
            xyz=array(j,b,attrs['POSITION'])
            if path.stem=='morrow_runtime':
                uv=np.column_stack([xyz[:,0]/(2*np.max(np.abs(xyz[:,0])))+.5,1-xyz[:,1]/xyz[:,1].max()])
            else:
                # span from the thorax to the wingtip, chord across the wing.
                uv=np.column_stack([xyz[:,2]/.36+.52,1-np.abs(xyz[:,0])/.42])
            uv=np.clip(uv,0,1).astype('<f4')
            while len(b)%4:b.append(0)
            start=len(b);b.extend(uv.tobytes())
            j['bufferViews'].append(dict(buffer=0,byteOffset=start,byteLength=uv.nbytes,target=34962))
            j['accessors'].append(dict(bufferView=len(j['bufferViews'])-1,componentType=5126,count=len(uv),type='VEC2',min=uv.min(0).tolist(),max=uv.max(0).tolist()))
            attrs['TEXCOORD_0']=len(j['accessors'])-1
            changes.append(mesh['name'])
    j['buffers'][0]['byteLength']=len(b)
    encoded=json.dumps(j,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    b+=b'\0'*((-len(b))%4)
    result=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(b))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(b),b'BIN\0')+b
    temporary=path.with_suffix('.tmp.glb');temporary.write_bytes(result);os.replace(temporary,path)
    # A UV addition must never alter anatomy or the original PBR reference.
    old,oldbin=read_glb(backup/path.name); new,newbin=read_glb(path)
    assert old['nodes']==new['nodes'] and old['materials']==new['materials']
    for om,nm in zip(old['meshes'],new['meshes']):
        assert len(om['primitives'])==len(nm['primitives'])
        for op,np_ in zip(om['primitives'],nm['primitives']):
            for attr in ['POSITION','NORMAL']:
                assert np.array_equal(array(old,oldbin,op['attributes'][attr]),array(new,newbin,np_['attributes'][attr]))
            assert np.array_equal(array(old,oldbin,op['indices']),array(new,newbin,np_['indices']))
    return dict(path=str(path.relative_to(ROOT)),uv_added_to=changes,positions_normals_indices_nodes_materials_unchanged=True,sha256=hashlib.sha256(result).hexdigest())

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--backup-dir')
    parser.add_argument('--maps-only',action='store_true',help='Rebuild eight maps without touching GLBs.')
    args=parser.parse_args()
    if args.maps_only:
        maps()
        print(json.dumps(dict(resolution=N,roles=4,maps=8,glbs_changed=False)))
        raise SystemExit(0)
    if not args.backup_dir: parser.error('--backup-dir is required unless --maps-only is used')
    backup=Path(args.backup_dir);maps()
    report=[add_uv(ROOT/'godot/assets'/name,backup) for name in ['visual_fauna/morrow_runtime.glb','visual_microfauna/shore_flier.glb']]
    (backup.parent/'map-build.json').write_text(json.dumps(dict(resolution=N,roles=4,maps=8,glb=report),indent=2),encoding='utf-8')
    print(json.dumps(report))
