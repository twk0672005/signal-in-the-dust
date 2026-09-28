"""Reopen all native source files and record observable mesh/transforms/material state."""
import bpy, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art-source/visual_flora'
OUT=ROOT/'evidence/visual-upgrade-20260923/flora-authoring'
reports=[]
for name in ['canopy','sails','pods','cups','mat','spores']:
    path=SOURCE/(name+'.blend');bpy.ops.wm.open_mainfile(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    entry={'family':name,'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'objects':len(bpy.context.scene.objects),'meshObjects':len(meshes),
        'triangles':sum(len(o.data.polygons) for o in meshes),
        'materialSlots':sum(len(o.data.materials) for o in meshes),
        'meshesMissingUV':sum(not len(o.data.uv_layers) for o in meshes),
        'nonIdentityObjectScales':[o.name for o in meshes if max(abs(v-1) for v in o.scale)>1e-6],
        'actions':len(bpy.data.actions),'cameras':sum(o.type=='CAMERA' for o in bpy.context.scene.objects),
        'units':bpy.context.scene.unit_settings.system,'scaleLength':bpy.context.scene.unit_settings.scale_length,
        'purpose':'Native editable geometry source; inspection cameras/lights intentionally live in separate GLB readback renderer.'}
    assert entry['meshesMissingUV']==0 and not entry['nonIdentityObjectScales'] and entry['units']=='METRIC'
    reports.append(entry)
    print('BLEND_READBACK '+json.dumps(entry),flush=True)
(OUT/'blend-readback.json').write_text(json.dumps({'blender':bpy.app.version_string,'assets':reports},indent=2),encoding='utf8')
