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
    rings=.5+.5*np.sin(2*np.pi*(radial*13+.13*np.sin(u*2*np.pi*5)))
    growth=smooth(.62,.93,rings)*smooth(.13,.9,radial)
    growth*=1-smooth(.90,.985,radial)
    lip=smooth(.92,.985,radial)
    cracks=np.exp(-(np.sin(2*np.pi*(u*19+.035*np.sin(radial*18)))/.095)**2)*smooth(.62,.96,radial)
    cracks*=1-smooth(.88,.97,radial) # The side-wall UV collapses at the lip; no stretched cracks there.
    fine=.5+.5*np.sin(u*2*np.pi*83+np.sin(radial*38))*np.sin(radial*2*np.pi*71)
    pigment=.78-.24*growth-.24*cracks-.15*smooth(.68,.93,radial)+.20*lip+.035*(fine-.5)
    assert np.ptp(pigment[0]) < 1e-5, 'Collapsed lip UV must not turn surface marks into side-wall stripes.'
    height=.47+.10*growth-.10*cracks+.06*lip+.008*(fine-.5)
    save('scute',pigment,.68+.20*growth-.24*lip,lip*(1-cracks),height,.055)

    # Main vein curves coincide with the eight authored load-bearing fingers:
    # s=end-.09*(1-t). Smaller branches span those structural bays.
    veins=np.zeros_like(u); capillary=np.zeros_like(u)
    for k,end in enumerate([.16,.28,.40,.52,.64,.76,.88,.96]):
        center=end-.09*(1-t)
        veins=np.maximum(veins,np.exp(-((u-center)/(.0025+.002*(1-t)))**2))
        for j in range(1,8):
            attach=j/9+.012*math.sin(k+j)
            for side in [-1,1]:
                d=side*(u-center)
                branch_t=attach+d*1.4+.35*d*d
                mask=smooth(0,.009,d)*(1-smooth(.042,.059,d))
                line=np.exp(-((t-branch_t)/.0028)**2)*mask
                capillary=np.maximum(capillary,line)
    edge=np.maximum(1-smooth(.015,.06,t),smooth(.955,.995,t))
    bays=.5+.5*np.sin(2*np.pi*(u*8+.09*(1-t)))
    fiber=.5+.5*np.sin(2*np.pi*(t*70+u*3))
    thickness=.22+.52*veins+.19*capillary+.24*edge
    pigment=.72+.13*bays-.34*veins-.18*capillary-.12*edge+.018*(fiber-.5)
    save('fan',pigment,.50+.18*veins+.13*capillary,capillary*.32+edge*.4,thickness,.010)

    # Morrow fronds and small flier wings: a central rachis with swept gills.
    x=(u-.5)*2
    mid=np.exp(-(x/.025)**2)
    branch_phase=(t-.28*np.abs(x)-.08*x*x)*18
    branch=np.exp(-(np.sin(branch_phase*np.pi)/.16)**2)*smooth(.025,.10,np.abs(x))
    rim=smooth(.82,.99,np.abs(x))
    height=.25+.42*mid+.18*branch+.12*rim
    save('frond',.74-.27*mid-.23*branch-.13*rim,.53+.2*branch,mid*.25+branch*.12,height,.016)

    # Fine overlapping dermal scales, deliberately lower contrast than armor.
    row=np.floor(v*26); xcell=np.mod(u*30+.5*np.mod(row,2),1)-.5
    ycell=np.mod(v*26,1)
    seam=np.exp(-((ycell-(.24+.68*np.sqrt(np.maximum(0,1-(xcell*2)**2))))/.07)**2)
    save('dermis',.72-.17*seam,.60+.15*seam,np.zeros_like(u),.45-.09*seam,.018)

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
    parser=argparse.ArgumentParser();parser.add_argument('--backup-dir',required=True);args=parser.parse_args()
    backup=Path(args.backup_dir);maps()
    report=[add_uv(ROOT/'godot/assets'/name,backup) for name in ['visual_fauna/morrow_runtime.glb','visual_microfauna/shore_flier.glb']]
    (backup.parent/'map-build.json').write_text(json.dumps(dict(resolution=N,roles=4,maps=8,glb=report),indent=2),encoding='utf-8')
    print(json.dumps(report))
