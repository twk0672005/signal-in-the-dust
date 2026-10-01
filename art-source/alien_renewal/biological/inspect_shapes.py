"""CPU GLB read-back front/back views, for geometry inspection only."""
import bpy, math, json, hashlib, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
EVID=ROOT/'evidence/alien-renewal-20260930T200644Z/biological'
records=[]
requested=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--species=')), 'veyra,aeral,morrow,rover').split(',')
for kind,path in [('veyra','assets/visual_fauna/veyra_runtime.glb'),('aeral','assets/visual_fauna/aeral_runtime.glb'),
                  ('morrow','assets/visual_fauna/morrow_runtime.glb'),('rover','assets/models/rover.glb')]:
    if kind not in requested:continue
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    asset=ROOT/'godot'/path;bpy.ops.import_scene.gltf(filepath=str(asset))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    low=Vector([min(p[i] for p in points) for i in range(3)]);high=Vector([max(p[i] for p in points) for i in range(3)])
    target=(low+high)*.5;size=max(high-low)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.resolution_x=1056;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('Inspection daylight');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.62,.70,.71,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,low.z-.02-(.5 if kind=='aeral' else 0)))
    plane=bpy.context.object;plane.name='GEO-inspection floor'
    mat=bpy.data.materials.new('MAT-inspection chalk');mat.diffuse_color=(.27,.25,.20,1);mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.27,.25,.20,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.86;plane.data.materials.append(mat)
    bpy.ops.object.light_add(type='SUN');sun=bpy.context.object;sun.name='LGT-inspection dawn';sun.data.energy=1.55;sun.data.angle=.07;sun.data.color=(1,.82,.60)
    sun.rotation_euler=(-Vector((4,-5,6))).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();camera=bpy.context.object;camera.name='CAM-inspection';scene.camera=camera
    camera.data.type='ORTHO';camera.data.ortho_scale=size*1.75
    for view,direction in [('front',Vector((1.0,1.3,.65))),('back',Vector((-1.0,-1.3,.65)))]:
        camera.location=target+direction*size
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        destination=EVID/f'{kind}-GLB-{view}.png';scene.render.filepath=str(destination)
        bpy.ops.render.render(write_still=True)
        records.append({'kind':kind,'view':view,'asset':str(asset.relative_to(ROOT)),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
                        'image':str(destination.relative_to(ROOT)),'bounds_blender':[list(low),list(high)],'device':'CPU','samples':16})
        print('SHAPE_INSPECTION',kind,view,flush=True)
previous=EVID/'shape-inspection.json'
if previous.exists():records=[r for r in json.loads(previous.read_text())['views'] if r['kind'] not in requested]+records
previous.write_text(json.dumps({'kind':'CPU_GLTF_geometry_readback_not_game_visual_or_performance_proof','views':records},indent=2),encoding='utf-8')
