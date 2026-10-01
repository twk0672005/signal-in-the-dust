"""Reopen the editable source and capture geometry/material previews on CPU."""
import bpy, math, json, time, os
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
EVIDENCE=ROOT/'evidence/alien-renewal-20260930T200644Z/flora/repair-02'
bpy.ops.wm.open_mainfile(filepath=str(Path(__file__).parent/'listening-flora.blend'))
scene=bpy.context.scene
missing=[image.name for image in bpy.data.images if image.source=='FILE' and not image.packed_file and not Path(bpy.path.abspath(image.filepath)).is_file()]
assert not missing, missing
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
scene.cycles.use_denoising=True
scene.render.resolution_x=1120;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.67,.73,.75,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.70
roots={obj.name:obj for obj in scene.objects if obj.type=='EMPTY'}
bpy.ops.mesh.primitive_plane_add(size=70,location=(0,0,-.13))
ground=bpy.context.object;ground.name='GEO-preview-ground'
mat=bpy.data.materials.new('Preview dry sediment');mat.diffuse_color=(.29,.31,.28,1);mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.29,.31,.28,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.94
ground.data.materials.append(mat)
bpy.ops.object.light_add(type='AREA',location=(-9,-12,17))
light=bpy.context.object;light.name='CPU-preview-key';light.data.energy=2200;light.data.size=12
light.data.color=(1,.86,.68);light.rotation_euler=(Vector((0,0,3))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(13,-19,8))
camera=bpy.context.object;camera.name='CPU-preview-camera';camera.data.lens=48;scene.camera=camera
camera.rotation_euler=(Vector((0,0,3.3))-camera.location).to_track_quat('-Z','Y').to_euler()
records=[]
for region in ['aurora','ember','veil','pale']:
    wanted={region+'_crown',region+'_fork',region+'_floor'}
    for obj in scene.objects:
        if obj.type=='MESH' and obj!=ground:obj.hide_render=obj.parent is None or obj.parent.name not in wanted
    roots[region+'_crown'].location=(-2,1,0)
    roots[region+'_fork'].location=(2.8,-.1,0)
    roots[region+'_floor'].location=(.4,-3.1,0)
    started=time.monotonic();scene.render.filepath=str(EVIDENCE/(region+'-cpu-material-preview.png'))
    bpy.ops.render.render(write_still=True)
    records.append({'region':region,'seconds':round(time.monotonic()-started,3),'image':scene.render.filepath})
    for name in wanted:roots[name].location=(0,0,0)
(EVIDENCE/'cpu-preview-reopen.json').write_text(json.dumps({'kind':'CPU asset previews; no gameplay or Web acceptance','blender':bpy.app.version_string,'device':scene.cycles.device,'appdata':os.environ.get('APPDATA'),'editable_family_roots':len(roots),'missing_images':missing,'captures':records},indent=2),encoding='utf-8')
print('FLORA_CPU_PREVIEWS '+json.dumps(records))
