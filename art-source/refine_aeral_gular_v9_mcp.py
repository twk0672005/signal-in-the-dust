"""Remove the patch-like edge identified in v8; sculpt folds into existing skin."""
import bpy
import math
from pathlib import Path

ROOT=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
assert bpy.data.filepath.endswith('aeral-mcp-secondary-v8.blend')
body=bpy.data.objects['FormV6_continuous_head_chest']
patch=bpy.data.objects['FormV8_continuous_pleated_gular_organ']
patch.hide_render=True;patch.hide_set(True)
assert body.data.shape_keys is None
body.shape_key_add(name='Basis')
key=body.shape_key_add(name='Gular_primary_folds')
changed=0
for i,vertex in enumerate(body.data.vertices):
    x,y,z=vertex.co
    t=(2.98-z)/.88
    if not 0<t<1 or vertex.normal.y<.35:continue
    width=.55*(math.sin(math.pi*(.10+.83*t))**.5)
    v=x/width
    if abs(v)>=1:continue
    profile=(.5+.5*math.cos(v*math.pi*4+.28*math.sin(t*math.pi)))**3
    envelope=(math.sin(math.pi*t)**.8)*max(0,1-v*v)**.8
    key.data[i].co.y += (.025+.09*profile)*envelope
    changed+=1
key.value=1.0
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/visual_fauna/aeral-mcp-secondary-v9.blend'))
result={'kind':'localized medium-scale organ shape key, no separate patch','file':bpy.data.filepath,'localizedVertices':changed,'totalBodyVertices':len(body.data.vertices),'unchanged':'main body proportions, shoulders, hips, feet/perch and v8 wings','accepted':False}
