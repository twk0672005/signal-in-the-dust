"""Expedition finish for the existing rover; isolated Blender 5.2 background.

Reuses art-source/signal-in-the-dust.blend, preserves seven body/wheel nodes,
adds visible hood hardware, and bakes original local weathering into one atlas.
No external asset or add-on. Runtime driving/collision/cameras remain unchanged.
"""
import bpy, bmesh, math, json, hashlib, sys
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(__file__).resolve().parent
sys.path.insert(0,str(SOURCE))
from repair_tangents import repair_singular_tangents
OUT=SOURCE/'maps'
EVID=ROOT/'evidence/alien-renewal-20260930T200644Z/biological'
for p in (SOURCE,OUT,EVID):p.mkdir(parents=True,exist_ok=True)
source=ROOT/'art-source/signal-in-the-dust.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
objects=[o for o in bpy.context.scene.objects if o.name.startswith(('rover_body','wheel_'))]
for o in list(bpy.context.scene.objects):
    if o not in objects:bpy.data.objects.remove(o,do_unlink=True)
for o in objects:o.hide_set(False);o.hide_render=False
body=bpy.data.objects['rover_body']
pivots={o.name:[list(row) for row in o.matrix_local] for o in objects}

def linear(value):
    c=[int(value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in c)

def constant_mat(name,color,rough=.7,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(*linear(color),1)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    return m

graphite=bpy.data.materials['graphite structure'];paint=bpy.data.materials['worn ceramic ivory'];metal=bpy.data.materials['exposed titanium']
def cube(name,loc,size,mat,bevel=.007):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Soft machined corners','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

hardware=[]
# The existing hood is sloped, so the two lids and their seam follow that plane.
for x in [-.25,.25]:
    lid=cube('GEO-hood access lid',(x,.87,1.071),(.46,.39,.015),paint,.008);lid.rotation_euler.x=-.15;hardware.append(lid)
    for dx in [-.185,.185]:
        for y in [.72,1.02]:
            z=1.085-(y-.87)*.15
            hardware.append(cube('GEO-captive hood bolt',(x+dx,y,z),(.021,.021,.006),metal,.003))
    for y in [.685,1.055]:
        z=1.083-(y-.87)*.15
        hardware.append(cube('GEO-low lid hinge',(x,y,z),(.12,.025,.012),metal,.004))
hardware.append(cube('GEO-dark service seam',(0,.87,1.078),(.008,.42,.008),graphite,.001))
# Low, useful ridges break the long blank hood without changing its silhouette.
for x in [-.40,.40]:
    rib=cube('GEO-hood stiffening edge',(x,.86,1.076),(.017,.38,.013),metal,.004);rib.rotation_euler.x=-.15;hardware.append(rib)
mark=constant_mat('faded field markings','42554f',.81)
for x in [-.10,-.065,-.03]:hardware.append(cube('GEO-weathered field stripe',(x,.91,1.082),(.012,.075,.002),mark,0))
# Two ochre lids identify the sample and power service bays within the existing
# panel footprints. Their physical edges stay below the first-person sightline.
dust=bpy.data.materials['ochre dust']
for x,y in [(-.42,-.66),(.42,-.10)]:
    hardware.append(cube('GEO-ochre service bay',(x,y,1.218),(.32,.43,.009),dust,.005))
bpy.ops.object.select_all(action='DESELECT')
for o in [body]+hardware:o.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
assert pivots=={o.name:[list(row) for row in o.matrix_local] for o in objects},'Rover pivot moved'
# Keep the full machined body; remove redundant tyre bevels before the shared
# atlas is made. Six original wheel nodes and their axle transforms survive.
for o in objects:
    if not o.name.startswith('wheel_'):continue
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Tyre distance simplification','DECIMATE');mod.ratio=.76
    bpy.ops.object.modifier_apply(modifier=mod.name)

# The inherited engraving/bevels include zero-area triangles. Remove these
# before UV packing so they cannot emit invalid tangent frames or waste draws.
degenerate_removed=0
for o in objects:
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    invalid=[f for f in bm.faces if f.calc_area()<5e-11]
    degenerate_removed+=len(invalid)
    if invalid:bmesh.ops.delete(bm,geom=invalid,context='FACES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data);bm.free();o.data.update()


scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=4
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.bake.margin=6;scene.render.bake.use_clear=True

materials=set(m for o in objects for m in o.data.materials)
settings={
    'graphite structure':('303e3f',.69,0),
    'worn ceramic ivory':('d5cdb5',.63,0),
    'exposed titanium':('92978b',.34,1),
    'ochre dust':('ac8349',.90,0),
    'amber instrument glass':('bf914e',.20,0),
    'coated optic':('214944',.14,0),
    'dusty grooved tyre':('3d4540',.90,0),
    'faded field markings':('42554f',.81,0),
}
for m in materials:
    color,rough,metallic=settings[m.name]
    nodes=m.node_tree.nodes;nodes.clear();links=m.node_tree.links
    bs=nodes.new('ShaderNodeBsdfPrincipled');bs.name='Export PBR';out=nodes.new('ShaderNodeOutputMaterial')
    links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bs.inputs['Base Color'].default_value=(*linear(color),1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metallic
    if 'glass' in m.name:
        bs.inputs['Emission Color'].default_value=(*linear(color),1);bs.inputs['Emission Strength'].default_value=.16
    if 'optic' in m.name or 'glass' in m.name:bs.inputs['Coat Weight'].default_value=.65;continue
    geo=nodes.new('ShaderNodeNewGeometry')
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1.8;noise.inputs['Detail'].default_value=2;links.new(geo.outputs['Position'],noise.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*[c*.97 for c in linear(color)],1);ramp.color_ramp.elements[1].color=(*[min(1,c*1.03) for c in linear(color)],1)
    links.new(noise.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
    map_range=nodes.new('ShaderNodeMapRange');map_range.inputs['To Min'].default_value=rough-.025;map_range.inputs['To Max'].default_value=min(.98,rough+.025)
    links.new(noise.outputs['Fac'],map_range.inputs['Value']);links.new(map_range.outputs['Result'],bs.inputs['Roughness'])
    fine=nodes.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=105;fine.inputs['Detail'].default_value=1.5;links.new(geo.outputs['Position'],fine.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.00022 if metallic else .00045
    links.new(fine.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    if m==paint:
        # Convex edge wear and sparse pits expose metal; sheltered faces retain
        # their coating. The physical 0/1 coverage is filtered by the baked map.
        edge=nodes.new('ShaderNodeValToRGB');edge.color_ramp.elements[0].position=.53;edge.color_ramp.elements[1].position=.60
        links.new(geo.outputs['Pointiness'],edge.inputs['Fac'])
        multiply=nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY';links.new(edge.outputs['Color'],multiply.inputs[0]);links.new(fine.outputs['Fac'],multiply.inputs[1])
        threshold=nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=.64;links.new(multiply.outputs[0],threshold.inputs[0])
        mix=nodes.new('ShaderNodeMixRGB');mix.inputs[2].default_value=(*linear('7a8481'),1);links.new(threshold.outputs[0],mix.inputs[0]);links.new(ramp.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],bs.inputs['Base Color']);links.new(threshold.outputs[0],bs.inputs['Metallic'])

# One shared 1024 atlas, uniquely packed across the seven moving objects.
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=body
for o in objects:
    for uv in list(o.data.uv_layers):o.data.uv_layers.remove(uv)
    o.data.uv_layers.new(name='ExpeditionFinish')
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.20,island_margin=.004,scale_to_bounds=True)
bpy.ops.object.mode_set(mode='OBJECT')
# Reserve the upper half of the atlas for the near-camera paint on the deck and
# hood. Other parts share the lower half at their actual smaller screen size.
hero_faces=0
for o in objects:
    uv=o.data.uv_layers.active
    for value in uv.data:value.uv=(.01+value.uv.x*.98,.01+value.uv.y*.47)
    if o!=body:continue
    for p in o.data.polygons:
        if o.data.materials[p.material_index]!=paint or p.normal.z<.72:continue
        pts=[o.matrix_world@o.data.vertices[i].co for i in p.vertices]
        if min(v.z for v in pts)<.98 or min(v.y for v in pts)<.20 or max(v.y for v in pts)>1.32:continue
        for l in p.loop_indices:
            v=o.matrix_world@o.data.vertices[o.data.loops[l].vertex_index].co
            uv.data[l].uv=(.03+(v.x+.62)/1.24*.94,.52+(v.y-.20)/1.12*.46)
        hero_faces+=1
for o in objects:
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
images={}
for channel in ['color','rough','metal','normal','ao']:
    image=bpy.data.images.new('rover_'+channel,width=1024,height=1024,alpha=False,float_buffer=False)
    image.colorspace_settings.name='sRGB' if channel=='color' else 'Non-Color'
    for m in materials:
        nodes=m.node_tree.nodes
        target=nodes.new('ShaderNodeTexImage');target.name='Bake target';target.image=image;nodes.active=target
        bs=nodes.get('Export PBR');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
        if channel in ['color','rough','metal']:
            emission=nodes.new('ShaderNodeEmission');emission.name='Bake field'
            input=bs.inputs[{'color':'Base Color','rough':'Roughness','metal':'Metallic'}[channel]]
            if input.is_linked:m.node_tree.links.new(input.links[0].from_socket,emission.inputs['Color'])
            else:
                value=input.default_value;emission.inputs['Color'].default_value=tuple(value) if channel=='color' else (value,value,value,1)
            m.node_tree.links.new(emission.outputs[0],out.inputs['Surface'])
        else:m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bpy.ops.object.bake(type='EMIT' if channel in ['color','rough','metal'] else 'NORMAL' if channel=='normal' else 'AO',margin=6)
    image.filepath_raw=str(OUT/f'rover_{channel}.png');image.file_format='PNG';image.save()
    images[channel]=image
    for m in materials:
        for n in list(m.node_tree.nodes):
            if n.name in ('Bake field','Bake target'):m.node_tree.nodes.remove(n)
    print('ROVER_BAKED',channel,flush=True)

# Retain geometric occlusion in the fixed albedo, and package rough/metal into
# the glTF ORM layout. Metallic values remain binary before texture filtering.
pixels={k:np.array(image.pixels[:],dtype=np.float32).reshape((1024,1024,4)) for k,image in images.items()}
assert np.isfinite(pixels['color']).all()
pixels['color'][:,:,:3]*=(.70+.30*pixels['ao'][:,:,:3])
images['color'].pixels.foreach_set(pixels['color'].reshape(-1));images['color'].save()
orm=bpy.data.images.new('rover_orm',width=1024,height=1024,alpha=False)
orm.colorspace_settings.name='Non-Color';packed=np.ones_like(pixels['rough']);packed[:,:,0]=pixels['ao'][:,:,0];packed[:,:,1]=pixels['rough'][:,:,0];packed[:,:,2]=pixels['metal'][:,:,0]
orm.pixels.foreach_set(packed.reshape(-1));orm.filepath_raw=str(OUT/'rover_orm.png');orm.file_format='PNG';orm.save()
for m in materials:
    nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Export PBR');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    color=nodes.new('ShaderNodeTexImage');color.image=images['color'];links.new(color.outputs['Color'],bs.inputs['Base Color'])
    data=nodes.new('ShaderNodeTexImage');data.image=orm;separate=nodes.new('ShaderNodeSeparateColor');links.new(data.outputs['Color'],separate.inputs['Color']);links.new(separate.outputs['Green'],bs.inputs['Roughness']);links.new(separate.outputs['Blue'],bs.inputs['Metallic'])
    normal=nodes.new('ShaderNodeTexImage');normal.image=images['normal'];nm=nodes.new('ShaderNodeNormalMap');links.new(normal.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
# Material identity is encoded in atlas pixels. Reuse a single opaque surface
# instead of keeping a draw surface for each coating/metal/rubber label.
common=graphite;common.name='Expedition coated metal and rubber atlas'
for o in objects:
    mapped=[m if any(token in m.name for token in ('glass','optic')) else common for m in o.data.materials]
    unique=list(dict.fromkeys(mapped));indices=[unique.index(mapped[p.material_index]) for p in o.data.polygons]
    o.data.materials.clear()
    for m in unique:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,indices):p.material_index=i
assert pivots=={o.name:[list(row) for row in o.matrix_local] for o in objects}
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'listening_rover.blend'))
dest=ROOT/'godot/assets/models/rover.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False,export_tangents=True)
singular_tangents=repair_singular_tangents(dest)
data=dest.read_bytes();length=int.from_bytes(data[12:16],'little');doc=json.loads(data[20:20+length])
report={'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'editable':str((SOURCE/'listening_rover.blend').relative_to(ROOT)),'file':str(dest.relative_to(ROOT)),'sha256':hashlib.sha256(data).hexdigest(),'blender':bpy.app.version_string,'build':bpy.app.build_hash.decode(),'provenance':'Reused project-original rover, including existing Blender Bfont mission-mark meshes, with locally authored hardware and geometry-based coating wear, dirt and fixed Cycles PBR bakes. No new downloads/fonts/add-ons.','bytes':len(data),'triangles':sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),'materials':len(doc['materials']),'textures':len(doc.get('textures',[])),'images':len(doc.get('images',[])),'primitives':sum(len(m['primitives']) for m in doc['meshes']),'nodes':[n['name'] for n in doc['nodes']],'rig_transforms_unchanged':True,'atlas_resolution':1024,'roughness_range':[float(packed[:,:,1].min()),float(packed[:,:,1].max())]}
assert report['triangles']<66000 and report['bytes']<10*1024*1024
report['singular_tangent_frames_repaired']=singular_tangents
report['derived_builder']='art-source/market_rover/rebuild_rover.py'
report['derived_builder_sha256']=hashlib.sha256((ROOT/'art-source/market_rover/rebuild_rover.py').read_bytes()).hexdigest()
report['wheel_simplification_ratio']=.76
report['zero_area_inherited_triangles_removed']=degenerate_removed
report['texel_allocation']={'atlas_resolution':1024,'near_camera_painted_faces':hero_faces,'near_camera_region':'upper 46 percent; about 775 texels/metre across the hood','other_surfaces':'lower 47 percent at their smaller driving-screen scale','broad_albedo_variation':'six percent maximum instead of 24 percent mottling','wear':'localized convex chips and geometric pre-existing scuffs; quiet coating dominant'}
(EVID/'rover-build.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
if '--skip-render' not in sys.argv:
    scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('Rover neutral day');world.use_nodes=True;scene.world=world;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.21,.24,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.03));floor=bpy.context.object;floor.data.materials.append(constant_mat('Display floor','6b7779',.91))
    target=Vector((0,0,.82))
    def aim(o,p=target):o.rotation_euler=(p-o.location).to_track_quat('-Z','Y').to_euler()
    for loc,power,color in [((4,3,7),1600,(1,.85,.69)),((-4,-3,5),1100,(.67,.84,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.size=5;light.data.color=color;aim(light)
    bpy.ops.object.camera_add(location=(3.3,4.2,2.7));camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=3.75;aim(camera)
    scene.render.filepath=str(EVID/'rover-neutral.png');bpy.ops.render.render(write_still=True)
    camera.data.type='PERSP';camera.data.angle=math.radians(72);camera.location=(0,.43,1.48);camera.rotation_euler=(math.pi/2-.10,0,math.pi)
    aim(camera,Vector((0,7,.75)));scene.render.filepath=str(EVID/'rover-first-person.png');bpy.ops.render.render(write_still=True)
print('LISTENING_ROVER_BUILD_PASS',json.dumps(report),flush=True)
