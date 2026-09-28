"""Run with Blender factory startup. Unshipped coupon, not a production creature."""
import bpy
import json
import math
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'evidence/visual-upgrade-20260923/tool-probe'
PROJECT = OUT / 'godot-probe'
PROJECT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# A two-joint folded membrane with UVs and deliberately preserved transparency.
bpy.ops.object.armature_add(location=(0, 0, 0))
rig = bpy.context.object
rig.name = 'ProbeRig'
bpy.ops.object.mode_set(mode='EDIT')
root = rig.data.edit_bones[0]
root.name = 'root'
root.head = (0, 0, 0)
root.tail = (0, 0, 1)
tip = rig.data.edit_bones.new('tip')
tip.head = root.tail
tip.tail = (0, 0, 2)
tip.parent = root
tip.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
vertices, faces = [], []
for z in range(9):
    for x in range(5):
        u, v = x / 4, z / 8
        vertices.append(((u - .5) * (1.2 - .35 * v), .06 * math.sin(u * math.pi), v * 2))
for z in range(8):
    for x in range(4):
        a = z * 5 + x
        faces.append((a, a + 1, a + 6, a + 5))
mesh = bpy.data.meshes.new('ProbeMembrane')
mesh.from_pydata(vertices, [], faces)
mesh.update()
obj = bpy.data.objects.new('ProbeMembrane', mesh)
bpy.context.collection.objects.link(obj)
obj.parent = rig
uv = mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
    polygon.use_smooth = True
    for loop in polygon.loop_indices:
        idx = mesh.loops[loop].vertex_index
        uv.data[loop].uv = ((idx % 5) / 4, (idx // 5) / 8)
for name in ('root', 'tip'):
    obj.vertex_groups.new(name=name)
for i, vertex in enumerate(vertices):
    weight = max(0, min(1, (vertex[2] - .65) / .7))
    obj.vertex_groups['root'].add([i], 1 - weight, 'REPLACE')
    obj.vertex_groups['tip'].add([i], weight, 'REPLACE')
modifier = obj.modifiers.new('ProbeArmature', 'ARMATURE')
modifier.object = rig
material = bpy.data.materials.new('Probe translucent membrane')
material.use_nodes = True
material.surface_render_method = 'DITHERED'
material.use_backface_culling = False
shader = material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value = (.07, .26, .4, 1)
shader.inputs['Roughness'].default_value = .38
shader.inputs['Alpha'].default_value = .72
shader.inputs['Emission Color'].default_value = (.01, .045, .065, 1)
shader.inputs['Emission Strength'].default_value = .3
texture = bpy.data.images.new('ProbeNormals', width=16, height=16, alpha=True)
texture.colorspace_settings.name = 'Non-Color'
texture.pixels = [component for y in range(16) for x in range(16)
                  for component in (.5 + .1 * math.sin(x * .7), .5, .98, 1)]
texture.filepath_raw = str(OUT / 'probe-normal.png')
texture.file_format = 'PNG'
texture.save()
texture.pack()
tex_node = material.node_tree.nodes.new('ShaderNodeTexImage')
tex_node.image = texture
normal = material.node_tree.nodes.new('ShaderNodeNormalMap')
material.node_tree.links.new(tex_node.outputs['Color'], normal.inputs['Color'])
material.node_tree.links.new(normal.outputs['Normal'], shader.inputs['Normal'])
obj.data.materials.append(material)
bone = rig.pose.bones['tip']
bone.rotation_mode = 'XYZ'
for frame, angle in ((1, 0), (16, .55), (31, 0)):
    bone.rotation_euler = (angle, 0, 0)
    bone.keyframe_insert(data_path='rotation_euler', frame=frame)
rig.animation_data.action.name = 'probe_fold'
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 31
bpy.context.scene.render.fps = 30
bpy.context.scene.frame_set(1)
blend = OUT / 'pipeline-probe.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
glb = PROJECT / 'pipeline-probe.glb'
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB',
                          export_animations=True, export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_skins=True, export_yup=True)
raw = glb.read_bytes()
length = int.from_bytes(raw[12:16], 'little')
gltf = json.loads(raw[20:20+length])
report = {
    'kind': 'unshipped_structural_pipeline_probe_not_art_quality',
    'blender': bpy.app.version_string,
    'meshes': len(gltf.get('meshes', [])), 'skins': len(gltf.get('skins', [])),
    'animations': [a.get('name') for a in gltf.get('animations', [])],
    'materials': gltf.get('materials', []),
    'textures': len(gltf.get('textures', [])),
    'glbBytes': len(raw), 'glbSha256': hashlib.sha256(raw).hexdigest(),
    'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'license': 'Original local test coupon; no external assets or runtime integration',
}
assert report['skins'] == 1 and report['animations'] and report['textures'] > 0
assert report['materials'][0].get('alphaMode') in ('BLEND', 'MASK')
(OUT / 'blender-export.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
(PROJECT / 'project.godot').write_text('''config_version=5
[application]
config/name="Unshipped pipeline probe"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
print('PIPELINE_EXPORT ' + json.dumps({k: v for k, v in report.items() if k != 'materials'}))
