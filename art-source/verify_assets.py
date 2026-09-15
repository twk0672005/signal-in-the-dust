"""Independent Blender import/read-back; run after build_assets.py."""
import bpy, json, hashlib, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
report=json.loads((ROOT/'evidence/assets/report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art-source/signal-in-the-dust.blend'))
report['blend_readback']={'objects':len(bpy.data.objects),'meshes':len(bpy.data.meshes),'cameras':len(bpy.data.cameras),'materials':len(bpy.data.materials),'actions':len(bpy.data.actions),'frame_start':bpy.context.scene.frame_start,'frame_end':bpy.context.scene.frame_end}
for key,a in report['assets'].items():
    path=ROOT/a['file'];data=path.read_bytes()
    assert data[:4]==b'glTF'
    chunk_len,chunk_type=struct.unpack_from('<II',data,12)
    doc=json.loads(data[20:20+chunk_len])
    a['glb_readback']={'nodes':[n.get('name','') for n in doc.get('nodes',[])],'meshes':len(doc.get('meshes',[])),'materials':len(doc.get('materials',[])),'animations':len(doc.get('animations',[])),'textures':len(doc.get('textures',[])),'primitives':sum(len(m['primitives']) for m in doc.get('meshes',[]))}
    a['glb_readback']['vertex_color_primitives']=sum('COLOR_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
    a['glb_readback']['external_image_dependencies']=[i['uri'] for i in doc.get('images',[]) if 'uri' in i]
    a['glb_readback']['node_transforms']={n.get('name',''):{k:n[k] for k in ('translation','rotation','scale','matrix') if k in n} for n in doc.get('nodes',[])}
    lo=a['bounds_blender']['min'];hi=a['bounds_blender']['max']
    a['bounds_godot']={'min':[lo[0],lo[2],-hi[1]],'max':[hi[0],hi[2],-lo[1]],'size':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]]}
    assert not a['glb_readback']['external_image_dependencies']
    if key=='rocks':assert a['glb_readback']['primitives']==5
    assert set(a['nodes']).issubset(set(a['glb_readback']['nodes']))
    assert hashlib.sha256(data).hexdigest()==a['sha256']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    mesh_objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    a['blender_import']={'mesh_count':len(mesh_objects),'mesh_names':[o.name for o in mesh_objects],'nonempty':all(len(o.data.vertices)>0 for o in mesh_objects)}
    assert len(mesh_objects)==len(a['nodes'])
    assert a['blender_import']['nonempty']
report['verification']='BLEND_AND_GLB_READBACK_PASS; Godot/runtime visual integration pending'
report['texture_sources']=[{'file':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'provenance':'Local mathutils noise tangent-normal synthesis; no downloaded content'} for p in (ROOT/'godot/assets/textures').glob('*.png')]
report['payload_bytes_including_external_source_textures']=report['total_glb_bytes']+sum(t['bytes'] for t in report['texture_sources'])
assert report['payload_bytes_including_external_source_textures']<=12*1024*1024
report['visual_review']={'first_pass_findings':['signal framing clipped top','roots looked disconnected','rock family too triangular/simple','six basalt surfaces per rock were wasteful'],'repair':['full-height signal framing','continuous tapered root geometry','fracture planes, smoothed weathering, continuous vertex-colour strata and original normal map','one surface per rock and two per rib','single-segment tyre-tread bevels reduce triangles'],'after_render_review':'PENDING'}
(ROOT/'evidence/assets/report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ASSET_READBACK_PASS')
