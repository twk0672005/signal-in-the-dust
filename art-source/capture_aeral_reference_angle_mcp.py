import bpy
from mathutils import Vector
bpy.context.scene.camera.location=(13,18,7.5)
bpy.context.scene.camera.rotation_euler=(Vector((0,-.25,3.8))-bpy.context.scene.camera.location).to_track_quat('-Z','Y').to_euler()
bpy.context.scene.render.filepath='C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923/evidence/visual-upgrade-20260923/aeral-mcp-forms-v4/clay-reference-three-quarter.png'
bpy.ops.render.render(write_still=True)
result={'kind':'additional same-handedness reference camera; Blender clay only','path':bpy.context.scene.render.filepath}
