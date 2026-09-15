"""Deterministic runtime rock LOD derived from the authored high GLB."""
import bpy,json,hashlib,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'godot/assets/models/rocks.glb'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in objects:
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('quarter-resolution rock LOD','DECIMATE');mod.ratio=.25
    bpy.ops.object.modifier_apply(modifier=mod.name)
path=ROOT/'godot/assets/models/rocks_low.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_apply=True,export_animations=False)
tris=0
for o in objects:o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
pts=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
data=path.read_bytes();doc=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
report_path=ROOT/'evidence/assets/report.json';report=json.loads(report_path.read_text())
report['assets']['rocks_low']={'file':str(path.relative_to(ROOT)),'nodes':[o.name for o in objects],'triangles':tris,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'bounds_blender':{'min':lo,'max':hi},'bounds_godot':{'min':[lo[0],lo[2],-hi[1]],'max':[hi[0],hi[2],-lo[1]]},'derivation':'build_rock_lod.py imports rocks.glb and deterministically decimates each mesh to 25 percent. Use for mid/far terrain.','glb_readback':{'meshes':len(doc['meshes']),'primitives':sum(len(m['primitives']) for m in doc['meshes']),'textures':len(doc.get('textures',[])),'vertex_color_primitives':sum('COLOR_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])}}
assert len(doc['meshes'])==5
assert report['assets']['rocks_low']['glb_readback']['primitives']==5
assert tris<=1600
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])==5
report['assets']['rocks_low']['blender_import']='PASS; five nonempty independent rock meshes'
report['total_triangles']=sum(a['triangles'] for a in report['assets'].values())
report['total_glb_bytes']=sum(a['bytes'] for a in report['assets'].values())
report['payload_bytes_including_external_source_textures']=report['total_glb_bytes']+sum(t['bytes'] for t in report['texture_sources'])
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ROCK_LOD_READBACK_PASS',tris,len(data))
