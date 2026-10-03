import bpy, math
from mathutils import Vector
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'evidence/world-tree-20261003/blender-v3'
OUT.mkdir(parents=True,exist_ok=True)
blend=Path(__file__).resolve().parent/'world_tree.blend'
bpy.ops.wm.open_mainfile(filepath=str(blend))
scene=bpy.context.scene
try: scene.render.engine='BLENDER_EEVEE_NEXT'
except TypeError: scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1200;scene.render.resolution_y=700;scene.render.resolution_percentage=75
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=0.35
world=scene.world;world.use_nodes=True;bg=world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(0.025,0.055,0.045,1);bg.inputs['Strength'].default_value=.34
def mat(name,color,rough=1.0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;return m
ground=bpy.data.meshes.new('GEO-v2_ground_mesh');bpy.ops.mesh.primitive_plane_add(size=2200,location=(0,0,-2));g=bpy.context.object;g.name='GEO-v2_ground';g.data.materials.append(mat('MAT-v2_ground',(0.025,0.019,0.012),.98))
def look(cam,target):cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
def setup_lights():
    for o in list(bpy.data.objects):
        if o.type=='LIGHT' or o.type=='CAMERA':bpy.data.objects.remove(o,do_unlink=True)
    sun_data=bpy.data.lights.new('LGT-v2_warm_sun','SUN');sun_data.energy=3.2;sun_data.color=(1.0,.58,.22);sun=bpy.data.objects.new('LGT-v2_warm_sun',sun_data);bpy.context.collection.objects.link(sun);sun.rotation_euler=(math.radians(28),math.radians(-28),math.radians(-35))
    fill_data=bpy.data.lights.new('LGT-v2_cool_fill','AREA');fill_data.energy=1200;fill_data.color=(.18,.32,.38);fill_data.shape='DISK';fill_data.size=80;fill=bpy.data.objects.new('LGT-v2_cool_fill',fill_data);bpy.context.collection.objects.link(fill);fill.location=(-180,120,160);look(fill,(0,0,110))
    gold_data=bpy.data.lights.new('LGT-v2_gold_spill','AREA');gold_data.energy=1800;gold_data.color=(1.0,.42,.08);gold_data.shape='DISK';gold_data.size=45;gold=bpy.data.objects.new('LGT-v2_gold_spill',gold_data);bpy.context.collection.objects.link(gold);gold.location=(0,50,72);look(gold,(0,0,95))
setup_lights()
cam_data=bpy.data.cameras.new('CAM-v2_tree');cam=bpy.data.objects.new('CAM-v2_tree',cam_data);bpy.context.collection.objects.link(cam);cam.data.lens=44;scene.camera=cam
views=[('far',(330,-520,155),(0,0,112)),('mid',(185,-290,92),(0,0,108)),('near',(62,-125,34),(0,0,62))]
for name,pos,target in views:
    cam.location=pos;look(cam,target);scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
print('BLENDER_V2_RENDERS',[(n,str(OUT/f'{n}.png') ) for n,_,_ in views])

