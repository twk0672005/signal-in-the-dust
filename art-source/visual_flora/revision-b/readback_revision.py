"""Reopen the two source files; distinguish preserved sculpt from export meshes."""
import bpy,json,hashlib,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'evidence/visual-upgrade-20260923/flora-authoring/revision-b'
rows=[]
for name in ('canopy','sails'):
    path=ROOT/'art-source/visual_flora/revision-b'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    sculpt=[o for o in bpy.context.scene.objects if o.name.startswith('SCULPT_')]
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('SCULPT_')]
    r={'family':name,'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'exportMeshes':len(meshes),
       'preservedSculptMeshes':len(sculpt),'sculptsHiddenFromRender':all(o.hide_render for o in sculpt),
       'missingUV':sum(not len(o.data.uv_layers) for o in meshes),'missingGrowthColor':sum(not len(o.data.color_attributes) for o in meshes),
       'nonIdentityScale':[o.name for o in meshes if max(abs(v-1) for v in o.scale)>1e-6],
       'units':bpy.context.scene.unit_settings.system,'scaleLength':bpy.context.scene.unit_settings.scale_length,'actions':len(bpy.data.actions)}
    assert r['missingUV']==0 and r['missingGrowthColor']==0 and not r['nonIdentityScale'] and r['sculptsHiddenFromRender']
    rows.append(r);print('REVISION_SOURCE_READBACK '+json.dumps(r),flush=True)
(OUT/'source-readback.json').write_text(json.dumps({'blender':bpy.app.version_string,'executable':bpy.app.binary_path,'processId':os.getpid(),'assets':rows},indent=2),encoding='utf8')
