"""One runnable read-back check for the four GLBs and preserved runtime contracts."""
import hashlib, json, math, struct, re
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
EVID=ROOT/'evidence/alien-renewal-20260930T200644Z/biological'
baseline=json.loads((EVID/'baseline.json').read_text())
rows=[]
for name,old in baseline.items():
    raw=(ROOT/name).read_bytes()
    magic,version,length=struct.unpack_from('<III',raw)
    assert (magic,version,length)==(0x46546c67,2,len(raw))
    count=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+count]);start=28+count
    def attribute(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
        item=np.dtype(dtype).itemsize
        return np.ndarray((a['count'],width),dtype=dtype,buffer=raw,offset=start+v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*item),item))
    nodes={n['name']:{k:v for k,v in n.items() if k in ('translation','rotation','scale','matrix','children')} for n in doc['nodes']}
    assert set(nodes)==set(old['nodes']), f'{name}: animation node contract changed'
    for node,values in old['nodes'].items():
        for key in ('translation','rotation','scale','matrix'):
            defaults={'translation':[0,0,0],'rotation':[0,0,0,1],'scale':[1,1,1],'matrix':np.eye(4).ravel().tolist()}
            assert np.allclose(values.get(key,defaults[key]),nodes[node].get(key,defaults[key]),atol=1e-6),f'{name}: {node} {key}'
        # glTF node ordering may change with material grouping. Compare names.
        before_children=[list(old['nodes'])[i] for i in values.get('children',[])]
        after_children=[doc['nodes'][i]['name'] for i in nodes[node].get('children',[])]
        assert before_children==after_children, f'{name}: {node} hierarchy'
    triangles=0;degenerate=0;vertices=0;surfaces=0;bounds=[]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            surfaces+=1;attrs=p['attributes'];positions=attribute(attrs['POSITION']);normals=attribute(attrs['NORMAL']);uv=attribute(attrs['TEXCOORD_0'])
            assert np.isfinite(positions).all() and np.isfinite(normals).all() and np.isfinite(uv).all()
            assert (np.linalg.norm(normals,axis=1)>.9).all()
            assert (uv>=-.001).all() and (uv<=1.001).all()
            tangent=attribute(attrs['TANGENT'])
            assert np.isfinite(tangent).all() and (np.linalg.norm(tangent[:,:3],axis=1)>.9).all()
            assert (np.abs(np.sum(tangent[:,:3]*normals,axis=1))<.01).all(), f'{name}: non-orthogonal tangent frame in {mesh.get("name", "")}'
            indices=attribute(p['indices']).ravel();assert indices.max()<len(positions) and len(indices)%3==0
            points=positions[indices.reshape(-1,3)]
            area=np.linalg.norm(np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]),axis=1)
            degenerate+=int((area<1e-10).sum());triangles+=len(points);vertices+=len(positions)
            bounds.append({'mesh':mesh.get('name',''),'min':positions.min(axis=0).tolist(),'max':positions.max(axis=0).tolist()})
            m=doc['materials'][p['material']]
            assert 'baseColorTexture' in m['pbrMetallicRoughness'] and 'metallicRoughnessTexture' in m['pbrMetallicRoughness'] and 'normalTexture' in m
    assert triangles<=old['triangles'] and surfaces<=old['surfaces']
    assert degenerate/max(1,triangles)<.001, f'{name}: degenerate triangles {degenerate}/{triangles}'
    assert all('bufferView' in i and not i.get('uri') for i in doc.get('images',[]))
    rows.append({'file':name,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'triangles':triangles,'surfaces':surfaces,
                 'before_triangles':old['triangles'],'before_surfaces':old['surfaces'],'vertices':vertices,'degenerate_triangles':degenerate,
                 'node_contract_unchanged':True,'embedded_images':len(doc['images']),'finite_uv_normals_tangents':True,'local_mesh_bounds':bounds})

def functions(text):
    starts=list(re.finditer(r'^func (\w+)\(',text,re.M));return {m.group(1):text[m.start():starts[i+1].start() if i+1<len(starts) else len(text)].rstrip() for i,m in enumerate(starts)}
rover_before=functions((EVID/'rover.gd').read_text(encoding='utf-8'))
rover_after=functions((ROOT/'godot/scripts/rover.gd').read_text(encoding='utf-8'))
assert set(rover_before)==set(rover_after)
assert all(rover_before[k]==rover_after[k] for k in rover_before if k!='_build_headlamps')
creature_before=functions((EVID/'creature_visual.gd').read_text(encoding='utf-8'))
creature_after=functions((ROOT/'godot/scripts/creature_visual.gd').read_text(encoding='utf-8'))
assert set(creature_before)==set(creature_after)
assert all(creature_before[k]==creature_after[k] for k in creature_before if k!='_configure_mesh')
result={'passed':True,'kind':'source_and_GLTF_readback_not_visual_acceptance','models':rows,
        'rover_functions_unchanged_except_lamp_colors':True,'creature_pose_and_debug_apis_unchanged':True,
        'before_triangles':sum(r['before_triangles'] for r in rows),'after_triangles':sum(r['triangles'] for r in rows)}
(EVID/'package-check.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='models'},indent=2))
