"""Repair only undefined/non-orthogonal exported tangent frames; retain UV/sign."""
import json
import numpy as np

def repair_singular_tangents(path):
    data=bytearray(path.read_bytes());size=int.from_bytes(data[12:16],'little')
    doc=json.loads(data[20:20+size]);start=28+size;repaired=0
    def attribute(index,width):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        return np.ndarray((a['count'],width),dtype='<f4',buffer=data,offset=start+v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*4),4))
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            attrs=p['attributes'];t=attribute(attrs['TANGENT'],4);n=attribute(attrs['NORMAL'],3)
            bad=(np.linalg.norm(t[:,:3],axis=1)<.9)|(np.abs((n*t[:,:3]).sum(axis=1))>.005)
            if not bad.any():continue
            normal=n[bad].copy();normal/=np.linalg.norm(normal,axis=1)[:,None]
            basis=t[bad,:3]-normal*(t[bad,:3]*normal).sum(axis=1)[:,None]
            undefined=np.linalg.norm(basis,axis=1)<1e-5
            ref=np.zeros_like(normal);ref[:,2]=1;ref[np.abs(normal[:,2])>.8]=[1,0,0]
            basis[undefined]=np.cross(ref[undefined],normal[undefined])
            basis/=np.linalg.norm(basis,axis=1)[:,None]
            assert np.isfinite(basis).all()
            t[bad,:3]=basis;repaired+=int(bad.sum())
    if repaired:path.write_bytes(data)
    return repaired
