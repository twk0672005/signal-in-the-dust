"""Non-mutating export of the immutable v9 candidate, selected visible specimen only."""
import bpy
import json
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
SOURCE=ROOT/'art-source/visual_fauna/aeral-mcp-secondary-v9.blend'
OUT=ROOT/'evidence/visual-upgrade-20260923/engine-specimen-probe'
PROJECT=OUT/'project'
PROJECT.mkdir(parents=True,exist_ok=True)
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
expected='b4def22c3b40e87c66405b50a2062e8927b8c116250c9c5307b09bfc50e278f6'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==expected
assert bpy.context.mode=='OBJECT'
root=bpy.data.objects['FormV6_Aeral']
perch=bpy.data.objects['FormV6_perch_support']
chosen=[]
for obj in bpy.context.scene.objects:
    ancestor=obj
    while ancestor and ancestor!=root:ancestor=ancestor.parent
    if (ancestor==root or obj==perch) and not obj.hide_render and obj.visible_get():chosen.append(obj)
old_selection=list(bpy.context.selected_objects)
old_active=bpy.context.view_layer.objects.active
bpy.ops.object.select_all(action='DESELECT')
for obj in chosen:obj.select_set(True)
bpy.context.view_layer.objects.active=root
glb=PROJECT/'aeral-v9-probe.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_animations=False,export_morph=True,export_morph_normal=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in old_selection:obj.select_set(True)
bpy.context.view_layer.objects.active=old_active
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==expected
raw=glb.read_bytes();n=int.from_bytes(raw[12:16],'little');doc=json.loads(raw[20:20+n])
evaluated=[];dg=bpy.context.evaluated_depsgraph_get()
for obj in chosen:
    if obj.type!='MESH':continue
    eval_obj=obj.evaluated_get(dg)
    evaluated += [eval_obj.matrix_world@Vector(corner) for corner in eval_obj.bound_box]
lo=[min(v[i] for v in evaluated) for i in range(3)]
hi=[max(v[i] for v in evaluated) for i in range(3)]
triangles=sum(doc['accessors'][p['indices']]['count']//3 if 'indices' in p else doc['accessors'][p['attributes']['POSITION']]['count']//3 for m in doc.get('meshes',[]) for p in m['primitives'])
report={'kind':'immutable_source_glb_import_probe','source':str(SOURCE),'sourceSha256':expected,
    'sourceUnchanged':True,'glb':str(glb),'glbSha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
    'meshes':len(doc.get('meshes',[])),'surfaces':sum(len(m['primitives']) for m in doc.get('meshes',[])),
    'triangles':triangles,'materials':len(doc.get('materials',[])),
    'morphTargets':[(m.get('name'),len(m['primitives'][0].get('targets',[])),m.get('weights')) for m in doc.get('meshes',[]) if m['primitives'][0].get('targets')],
    'blenderBounds':{'min':lo,'max':hi},'godotBoundsExpected':{'min':[lo[0],lo[2],-hi[1]],'max':[hi[0],hi[2],-lo[1]]},
    'selectedNames':[o.name for o in chosen],'includedPerch':True,'animations':len(doc.get('animations',[])),
    'externalImages':[image.get('uri') for image in doc.get('images',[]) if image.get('uri')],
    'productionAssetOverwritten':False,'visualAcceptance':False}
(OUT/'aeral-export.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
