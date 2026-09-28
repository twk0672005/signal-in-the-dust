import bpy
from pathlib import Path
from mathutils import Vector

root=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
creature=bpy.data.objects['FormV4_Aeral']
creature.location.z=-.065
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(root/'godot/assets/models/rover.glb'))
imported=[obj for obj in bpy.context.scene.objects if obj not in before]
reference=bpy.data.objects.new('FormV4_OriginalRoverScale',None)
bpy.context.scene.collection.objects.link(reference)
for obj in imported:
    if obj.parent is None:obj.parent=reference
    obj.name='FormV4_Rover_'+obj.name
reference.location=(-3.2,2.2,-.055)
scene=bpy.context.scene
scene.camera.location=(13,18,7.5)
scene.camera.rotation_euler=(Vector((0,-.25,3.7))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(root/'evidence/visual-upgrade-20260923/aeral-mcp-forms-v4/clay-reference-scale.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art-source/visual_fauna/aeral-mcp-forms-v4.blend'))
result={'kind':'neutral Blender MCP same-scene original rover scale inspection','path':scene.render.filepath,'creatureGroundShift':-.065,'referenceRoverPosition':list(reference.location),'accepted':False}
