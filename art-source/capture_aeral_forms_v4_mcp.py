import bpy
import json
from pathlib import Path
from mathutils import Vector

root=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
out=root/'evidence/visual-upgrade-20260923/aeral-mcp-forms-v4'
camera=bpy.context.scene.camera
target=Vector((0,-.25,3.8))
shots=[('clay-three-quarter',(-13,18,7.5)),('clay-front',(0,21,5)),('clay-side',(-22,0,5)),('clay-back',(0,-23,6))]
record=[]
for name,position in shots:
    camera.location=position
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    record.append({'name':name,'position':list(position),'target':list(target),'projection':'orthographic','scale':camera.data.ortho_scale})
result={'kind':'Blender MCP primary-form neutral renders; not Godot or Web proof','file':bpy.data.filepath,'shots':record,'emission':False,'textures':False,'productionAccepted':False}
(out/'receipt.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
