"""Independent binary geometry/material readback of handoff GLBs, Python + NumPy."""
import json, struct, hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'godot/assets/visual_flora/revision-b'
EVIDENCE=ROOT/'evidence/visual-upgrade-20260923/flora-authoring/revision-b'
DT={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def audit(p):
    raw=p.read_bytes();magic,version,total=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and total==len(raw)
    size,kind=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+size]);offset=20+size
    binsize,binkind=struct.unpack_from('<II',raw,offset);blob=raw[offset+8:offset+8+binsize]
    def accessor(i):
        a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dtype=np.dtype(DT[a['componentType']]);nc=NC[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',dtype.itemsize*nc)
        return np.ndarray((a['count'],nc),dtype=dtype,buffer=blob,offset=start,strides=(stride,dtype.itemsize))
    deg=0;triangles=0;badnorm=0;primitives=0
    for m in g.get('meshes',[]):
        for prim in m['primitives']:
            primitives+=1;attrs=prim['attributes'];assert all(k in attrs for k in ('POSITION','NORMAL','TEXCOORD_0'))
            pos=accessor(attrs['POSITION']);norm=accessor(attrs['NORMAL']);uv=accessor(attrs['TEXCOORD_0'])
            assert np.isfinite(pos).all() and np.isfinite(norm).all() and np.isfinite(uv).all()
            idx=accessor(prim['indices']).reshape(-1,3);assert idx.min()>=0 and idx.max()<len(pos)
            points=pos[idx].astype(np.float64);cross=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]);areas=np.linalg.norm(cross,axis=1)*.5
            deg+=int(np.count_nonzero(areas<1e-9));triangles+=len(idx)
            badnorm+=int(np.count_nonzero(np.abs(np.linalg.norm(norm,axis=1)-1)>.015))
    images=[]
    for im in g.get('images',[]):
        assert 'bufferView' in im and im['mimeType']=='image/png'
        view=g['bufferViews'][im['bufferView']];data=blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        width,height=struct.unpack_from('>II',data,16);images.append({'name':im.get('name'),'width':width,'height':height,'embedded':True})
    mats=[]
    for m in g.get('materials',[]):
        pbr=m['pbrMetallicRoughness']
        mats.append({'name':m.get('name'),'alphaMode':m.get('alphaMode','OPAQUE'),'doubleSided':m.get('doubleSided',False),
                     'baseColorTexture':'baseColorTexture' in pbr,'roughnessTexture':'metallicRoughnessTexture' in pbr,
                     'normalTexture':'normalTexture' in m,'emissiveTexture':'emissiveTexture' in m,
                     'emissiveFactor':m.get('emissiveFactor',[0,0,0])})
    result={'file':p.name,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'triangles':triangles,
        'meshCount':len(g['meshes']),'primitives':primitives,'degenerateTrianglesBelow1e-9m2':deg,'nonUnitNormals':badnorm,
        'finitePositionsNormalsUV':True,'allIndicesInBounds':True,'materials':mats,'images':images,
        'nonManifoldPolicy':'Open mineral overlay scales intentional. Thick tissue shells inspected visually; this audit does not claim global manifold topology.',
        'hasAnimations':bool(g.get('animations'))}
    assert badnorm==0,(p.name,badnorm)
    # Under 1e-9 m2 is a numerical sliver threshold, not necessarily zero-area.
    assert deg<max(10,triangles*.0002),(p.name,deg,triangles)
    return result
results=[audit(p) for p in sorted(OUT.glob('*.glb'))]
report={'validationBoundary':'Binary GLB data only; no engine import, collision, framerate, Web or final visual acceptance claim.',
        'status':'STRUCTURAL_READBACK_PASS','assets':results}
(EVIDENCE/'glb-structural-audit.json').write_text(json.dumps(report,indent=2),encoding='utf8')
for a in results:print(a['file'],a['triangles'],'triangles',a['degenerateTrianglesBelow1e-9m2'],'tiny triangles',a['nonUnitNormals'],'bad normals')
