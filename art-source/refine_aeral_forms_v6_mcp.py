"""Fuse scapular tissue into the continuous torso and define the gular volume.
Consumes the reviewed-lineage v5 working scene; saves a new v6, preserving v4/v5.
"""
import bpy
import runpy
from pathlib import Path

root=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
assert bpy.data.filepath.endswith('aeral-mcp-forms-v5.blend'), bpy.data.filepath
helpers=runpy.run_path(str(root/'art-source/build_visual_fauna.py'),run_name='geometry_helpers')
body=bpy.data.objects['FormV5_continuous_head_chest']
parent=bpy.data.objects['FormV5_Aeral']
skin=body.data.materials[0]
gular=helpers['loft']('FormV5_gular_chamber',[(1.05,2.51,.37,.29),(1.55,2.66,.57,.47),(1.94,2.87,.47,.40),(2.31,3.02,.21,.18),(2.46,3.05,.025,.04)],skin,sides=44,subdivisions=5,parent=parent)
parts=[body,gular]+[obj for obj in bpy.context.scene.objects if obj.name.startswith('FormV5_wing_root_muscle')]
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
body.data.remesh_voxel_size=.052
bpy.ops.object.voxel_remesh()
smooth=body.modifiers.new('Scapular tissue continuity','SMOOTH');smooth.factor=.6;smooth.iterations=5
bpy.ops.object.modifier_apply(modifier=smooth.name)
for polygon in body.data.polygons: polygon.use_smooth=True
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith('FormV5_'):obj.name=obj.name.replace('FormV5_','FormV6_',1)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art-source/visual_fauna/aeral-mcp-forms-v6.blend'))
result={'kind':'connected primary-form revision; no materials polish','file':bpy.data.filepath,'fusedObjects':len(parts),'bodyVertices':len(body.data.vertices),'bodyPolygons':len(body.data.polygons),'revision':'v4 findings: narrow hips/jointed grip from v5, connected scapula/gular chamber in v6','accepted':False}
