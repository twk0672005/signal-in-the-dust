"""Signal in the Dust: original deterministic authored geometry. Blender 5.2.1.
Run blender --background --factory-startup --python <this-file>.
Author axes: X right, Y forward, Z up. glTF conversion => Godot forward -Z.
"""
import bpy, math, random, json, hashlib, os, sys
from pathlib import Path
from mathutils import Vector, noise
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'godot/assets/models'
EVID = ROOT/'evidence/assets'
for p in (OUT, EVID): p.mkdir(parents=True, exist_ok=True)
random.seed(15092026)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.render.engine='CYCLES'; scene.cycles.samples=16
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.cycles.use_denoising=True
scene.render.resolution_x=1200; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.world.color=(.07,.07,.07)
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
materials={}
def mat(name,col,metal=0,rough=.5,emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF'); n.inputs['Base Color'].default_value=(*col,1)
    n.inputs['Metallic'].default_value=metal; n.inputs['Roughness'].default_value=rough
    if emission: n.inputs['Emission Color'].default_value=(*col,1); n.inputs['Emission Strength'].default_value=emission
    materials[name]=m; return m
ivory=mat('worn ceramic ivory',(.62,.58,.46),.45,.49)
edge=mat('exposed titanium',(.23,.255,.27),.85,.3)
dark=mat('graphite structure',(.045,.055,.061),.65,.49)
rubber=mat('dusty grooved tyre',(.055,.048,.038),.02,.86)
dust=mat('ochre dust',(.26,.105,.044),.05,.88)
amber=mat('amber instrument glass',(1,.29,.025),.3,.24,3)
lens=mat('coated optic',(.016,.032,.05),.6,.16)
cyan=mat('signal cyan core',(.02,.78,.87),.35,.25,3.5)
basalts=[mat('basalt stratum %02d'%i,(.035+i*.006,.042+i*.006,.053+i*.006),.12,.82) for i in range(6)]
def assign(o,m): o.data.materials.append(m); return o
def bevel(o,width=.025,segments=2):
    mod=o.modifiers.new('machined edge','BEVEL'); mod.width=width; mod.segments=segments
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def cube(name,loc,scale,m,bev=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name
    o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    assign(o,m)
    if bev: bevel(o,bev)
    return o
def cyl(name,loc,r,depth,m,axis='Z',verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
    o=bpy.context.object; o.name=name
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    assign(o,m); bevel(o,.008,2); return o
def rod(name,a,b,r,m,verts=10):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();assign(o,m);return o
def join(objects,name,pivot=(0,0,0)):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    scene.cursor.location=pivot;bpy.ops.object.origin_set(type='ORIGIN_CURSOR');return o
def newly(before):return [o for o in scene.objects if o.type=='MESH' and o not in before]
assets={}
before=set(scene.objects)
# Faceted pressure hull, flared nose, separated service panels and metal seams.
cube('belly',(0,0,.63),(1.14,1.86,.3),dark,.09)
cube('pressure hull',(0,-.04,.91),(1.22,1.79,.44),ivory,.12)
cube('forward instrument hood',(0,.88,.93),(1.10,.57,.25),ivory,.055).rotation_euler[0]=-.15
cube('deck rim',(0,-.05,1.13),(1.26,1.88,.085),edge,.035)
for x in [-.42,0,.42]:
    for y in [-.66,-.1,.46]:
        cube('bolted service panel',(x,y,1.18),(.38,.5,.06),ivory,.018)
        for dx in [-.145,.145]:
            for dy in [-.195,.195]:cyl('captive screw',(x+dx,y+dy,1.216),.011,.008,edge,verts=8)
for sign in [-1,1]:
    cube('side orange identification strip',(sign*.619,-.05,.93),(.016,1.11,.047),dust,.004)
    cube('side radiator surround',(sign*.64,-.46,.85),(.05,.60,.23),edge,.018)
    for i in range(10):cube('radiator fins',(sign*.675,-.70+i*.054,.85),(.04,.019,.18),dark,.003)
    # Three-segment rocker suspension, springs, steering knuckles.
    for a,b in [((sign*.52,.02,.7),(sign*.77,.60,.50)),((sign*.77,.60,.50),(sign*.78,1.0,.35)),((sign*.57,-.18,.69),(sign*.77,-.58,.48)),((sign*.77,-.58,.48),(sign*.78,-.95,.35)),((sign*.77,-.58,.48),(sign*.78,.05,.35))]:
        rod('rocker bogie',a,b,.046,edge)
    for y in [-.94,.03,.99]:
        cyl('axle',(sign*.76,y,.355),.09,.18,dark,'X')
        rod('damper',(sign*.57,y-.15,.72),(sign*.75,y,.41),.029,dark)
        rod('damper piston',(sign*.57,y-.15,.72),(sign*.69,y-.04,.52),.017,edge)
    for y in [.83,-.80]:
        rod('deck guard',(sign*.58,y,1.18),(sign*.58,y,1.33),.018,edge)
    rod('deck grab rail',(sign*.58,-.80,1.33),(sign*.58,.83,1.33),.018,edge)
    cube('lamp cage',(sign*.42,1.167,.94),(.24,.08,.145),dark,.025)
    cube('amber lamp',(sign*.42,1.212,.94),(.17,.024,.075),amber,.017)
    for dx in [-.04,.04]:rod('lamp protection',(sign*.42+dx,1.23,.884),(sign*.42+dx,1.23,.996),.008,edge)
    # Characterful wear: thin irregular exposed edge scuffs, deterministic geometry.
    for i in range(22):
        y=random.uniform(-.76,.77);z=random.uniform(.83,1.06)
        cube('chipped paint',(sign*.614,y,z),(.006,random.uniform(.018,.10),random.uniform(.003,.01)),edge,0)
# Rear energy canister, cable harness, mast, two asymmetric cameras and sample drill.
cube('rear battery',(0,-.91,1.31),(.68,.34,.21),dark,.035)
for x in [-.23,.23]:cube('battery clamps',(x,-.91,1.32),(.045,.38,.24),edge,.01)
cyl('mast bearing',(.02,.34,1.26),.135,.18,edge)
cyl('mast neck',(.02,.34,1.46),.057,.37,ivory)
cube('camera head',(.02,.36,1.66),(.48,.27,.20),ivory,.045)
cube('camera visor',(.02,.49,1.765),(.53,.36,.035),dark,.018)
for x,r in [(-.105,.065),(.155,.042)]:
    cyl('optical housing',(x,.522,1.665),r+.013,.062,edge,'Y')
    cyl('optical glass',(x,.557,1.665),r,.018,lens,'Y')
    cyl('optic pupil',(x,.57,1.665),r*.43,.01,dark,'Y')
rod('antenna whip',(-.47,-.66,1.22),(-.51,-.7,1.94),.009,edge)
cyl('antenna base',(-.47,-.66,1.27),.043,.17,dark)
rod('sampler arm',(.57,.53,.84),(.44,1.25,.5),.038,edge)
cyl('sampling probe',(.44,1.25,.42),.052,.23,dark)
for j in range(5):cyl('probe ring',(.44,1.25,.33+j*.04),.062,.012,edge)
# Precision engraved identification plates; text converted to mesh.
def lettering(text,loc,size,rotation,material):
    cu=bpy.data.curves.new('engraved type','FONT');cu.body=text;cu.size=size;cu.extrude=.0004
    o=bpy.data.objects.new('mission lettering',cu);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=rotation;assign(o,material)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
lettering('S I D / 0 6',(-.29,.63,1.217),.071,(0,0,0),dark)
lettering('FIELD SCIENCE',(-.28,-.31,1.217),.041,(0,0,0),dark)
body=join(newly(before),'rover_body')
rover=[body]
for sign in [-1,1]:
    for idx,y in enumerate([-.94,.03,.99]):
        before=set(scene.objects);x=sign*.81;z=.355
        cyl('tyre casing',(x,y,z),.345,.29,rubber,'X',40)
        for side in [-1,1]:
            cyl('reinforced tyre wall',(x+side*.145,y,z),.294,.023,rubber,'X',32)
        for i in range(28):
            t=2*math.pi*i/28
            for half in [-1,1]:
                o=cube('chevron tread',(x+half*.071,y+math.sin(t)*.338,z+math.cos(t)*.338),(.145,.035,.041),rubber,0)
                bevel(o,.005,1)
                o.rotation_euler[0]=-t;o.rotation_euler[2]=half*.25
        cyl('machined wheel rim',(x+sign*.164,y,z),.214,.036,edge,'X',24)
        cyl('recessed hub',(x+sign*.187,y,z),.15,.024,dark,'X',24)
        cyl('central hub',(x+sign*.207,y,z),.075,.046,ivory,'X',16)
        for i in range(8):
            t=i*math.pi/4
            cyl('rim lug',(x+sign*.205,y+math.sin(t)*.176,z+math.cos(t)*.176),.017,.022,ivory,'X',8)
        rover.append(join(newly(before),'wheel_%s_%02d'%('left' if sign<0 else 'right',idx+1),(x,y,z)))
assets['rover']=rover
# Signal: asymmetric organic basalt ribs with directional growth ridges and cyan inlays.
signal=[]
for j in range(8):
    angle=2*math.pi*j/8+.13
    height=6.4+1.9*(.5+.5*math.sin(j*2.4))
    verts=[];faces=[];rings=32;sides=14
    for k in range(rings):
        t=k/(rings-1)
        radius=1.65*(1-t)**1.0+.48*math.sin(t*math.pi)-.55*math.sin(t*math.pi*.72)
        center=Vector((math.cos(angle)*radius,math.sin(angle)*radius,height*t))
        width=(.12+.46*math.sin(math.pi*(t*.87+.1)))*(1-t**5)+.012
        for s in range(sides):
            a=s*math.tau/sides
            jag=1+.17*math.sin(k*2.3+s*1.9+j)+.08*math.sin(k*.73+s*3.2)
            # compressed blade section, central longitudinal ridge.
            v=center+Vector((math.cos(angle)*math.cos(a)*width*jag,math.sin(angle)*math.cos(a)*width*jag,0))+Vector((-math.sin(angle)*math.sin(a)*width*.49,math.cos(angle)*math.sin(a)*width*.49,0))
            verts.append(tuple(v))
    for k in range(rings-1):
        for s in range(sides):faces.append((k*sides+s,k*sides+(s+1)%sides,(k+1)*sides+(s+1)%sides,(k+1)*sides+s))
    faces.extend([tuple(reversed(range(sides))),tuple((rings-1)*sides+s for s in range(sides))])
    me=bpy.data.meshes.new('rib hand-shaped strata');me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new('rib_%02d'%(j+1),me);scene.collection.objects.link(o)
    for m in basalts+[cyan]:me.materials.append(m)
    for poly in me.polygons:
        s=poly.index%sides;k=poly.index//sides
        poly.material_index=6 if s==7 and 4<k<28 and k%8!=0 else (k//3+j+s)%6
    # Base pivot stays planted; integration rotates each named rib around its local origin.
    scene.cursor.location=(math.cos(angle)*1.65,math.sin(angle)*1.65,0)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    signal.append(o)
before=set(scene.objects)
for j in range(11):
    a=j*math.tau/11
    # Continuous tapered weathered roots, replacing visibly disconnected rods.
    rv=[];rf=[];rs=7;rr=15
    for k in range(rr):
        t=k/(rr-1);ang=a+.08*math.sin(t*5+j);dist=1.0+3.1*t
        width=.21*(1-t)**1.35+.005
        for s in range(rs):
            q=s*math.tau/rs;w=width*(1+.18*math.sin(k*1.3+s*2+j))
            rv.append((math.cos(ang)*dist-math.sin(ang)*math.cos(q)*w,math.sin(ang)*dist+math.cos(ang)*math.cos(q)*w,.065+.12*math.sin(t*math.pi)+math.sin(q)*w*.45))
    for k in range(rr-1):
        for s in range(rs):rf.append((k*rs+s,k*rs+(s+1)%rs,(k+1)*rs+(s+1)%rs,(k+1)*rs+s))
    me=bpy.data.meshes.new('continuous eroded root');me.from_pydata(rv,[],rf);me.update()
    o=bpy.data.objects.new('basalt root',me);scene.collection.objects.link(o);assign(o,basalts[j%6])
signal.append(join(newly(before),'signal_roots'))
assets['signal']=signal
# Five independent weathered basalt rocks, plus directional erosion and split seams.
rocks=[]
for j in range(5):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=.55)
    o=bpy.context.object;o.name='rock_%02d'%(j+1)
    for m in basalts:o.data.materials.append(m)
    for v in o.data.vertices:
        p=v.co.copy();n=noise.noise_vector(p*4.5+Vector((j*8,1,3)))
        p*=1+n.x*.20
        # Geological fracture planes produce chipped ledges instead of spheres.
        p.x=min(p.x,.36+.07*math.sin(j*2))
        p.y=max(p.y,-.38+.06*math.sin(j))
        if p.z>.10:p.x+=.07*math.sin(j*2.2)
        p.x*=1.05+(j%3)*.27;p.y*=.78+(j%2)*.24;p.z*=.65+j*.11
        p.z+=.035*math.sin(p.x*17+j)+.014*n.z
        if p.z<-.22:p.z=-.22+(p.z+.22)*.32
        p.x+=p.z*.3*(j-2)
        v.co=p
    minz=min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:v.co.z-=minz
    # Normalize footprint 1m: placement transforms belong to the runtime.
    mx=max(max(abs(v.co.x),abs(v.co.y)) for v in o.data.vertices)
    for v in o.data.vertices:v.co/=mx*2
    for f in o.data.polygons:
        f.material_index=max(0,min(5,int(2.5+noise.noise(f.center*17+Vector((j,0,0)))*5)))
        f.use_smooth=True
    rocks.append(o)
assets['rocks']=rocks
# Consolidate rock strata to one vertex-coloured material per rock. This keeps
# per-face mineral variation without six draw surfaces per terrain instance.
strata=mat('basalt vertex strata-vcol',(1,1,1),.12,.82)
vc=strata.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='weathering'
strata.node_tree.links.new(vc.outputs['Color'],strata.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
# Locally synthesized mineral micropores. Standard glTF tangent normal map;
# one shared 256px texture adds tactile erosion without geometry inflation.
texdir=ROOT/'godot/assets/textures';texdir.mkdir(parents=True,exist_ok=True)
normal_image=bpy.data.images.new('original basalt micropores',width=256,height=256)
normal_image.colorspace_settings.name='Non-Color'
pixels=[]
for y in range(256):
    for x in range(256):
        p=Vector((x*.19,y*.19,3.12));dx=noise.noise(p+Vector((.2,0,0)))-noise.noise(p-Vector((.2,0,0)));dy=noise.noise(p+Vector((0,.2,0)))-noise.noise(p-Vector((0,.2,0)))
        n=Vector((-dx*1.5,-dy*1.5,1)).normalized();pixels.extend((n.x*.5+.5,n.y*.5+.5,n.z*.5+.5,1))
normal_image.pixels=pixels;normal_image.filepath_raw=str(texdir/'basalt-normal.png');normal_image.file_format='PNG';normal_image.save();normal_image.pack()
tn=strata.node_tree.nodes.new('ShaderNodeTexImage');tn.image=normal_image
nm=strata.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.65
strata.node_tree.links.new(tn.outputs['Color'],nm.inputs['Color']);strata.node_tree.links.new(nm.outputs['Normal'],strata.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
for o in signal+rocks:
    me=o.data;col=me.color_attributes.new(name='weathering',type='BYTE_COLOR',domain='CORNER')
    uv=me.uv_layers.new(name='mineral UV')
    for face in me.polygons:
        for li in face.loop_indices:
            p=me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv=(p.x*2+p.z*.31,p.y*2+p.z*.73)
    indices=[]
    for face in me.polygons:
        old=me.materials[face.material_index]
        for li in face.loop_indices:
            colour=(1,1,1,1) if old==cyan else old.diffuse_color
            if o in rocks:
                p=me.vertices[me.loops[li].vertex_index].co
                value=.052+.011*math.sin(p.z*31+p.x*5)+.012*noise.noise(p*19)
                colour=(value*.86,value*.94,value*1.08,1)
            col.data[li].color=colour
        indices.append(1 if old==cyan else 0)
    me.materials.clear();me.materials.append(strata);me.materials.append(cyan)
    for face,i in zip(me.polygons,indices):face.material_index=i
# Export only the intended asset collection. Root origin and wheel/rib pivots survive.
report={'status':'AUTHORED_ASSET_CANDIDATE','blender':bpy.app.version_string,'blender_build_hash':bpy.app.build_hash.decode(),'seed':15092026,'source':'Original procedural geometry authored locally for Signal in the Dust. No downloaded assets or fonts. Blender bundled Bfont used for mission marks.','license':'Original asset geometry: project-owned, unrestricted project use. Blender Bfont mission marks derive from bundled font.','axes':'Blender +Y forward / +Z up -> glTF/Godot -Z forward / +Y up','animation':'No baked clips. Runtime owns wheel local X rotation and rib pivot transforms.','assets':{}}
for key,objects in assets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    path=OUT/(key+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False)
    pts=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
    tris=0
    for o in objects:o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    report['assets'][key]={'file':str(path.relative_to(ROOT)),'nodes':[o.name for o in objects],'triangles':tris,'bounds_blender':{'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)]},'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
# Source stores each asset in its own collection, separated only by visibility.
for key,objects in assets.items():
    coll=bpy.data.collections.new(key.upper()+' / export geometry');scene.collection.children.link(coll)
    for o in objects:
        for old in list(o.users_collection):old.objects.unlink(o)
        coll.objects.link(o)
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(4,5,3));camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.lens=50
def light(name,loc,power,size,color):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;aim(o,(0,0,1))
light('warm softbox',(3,4,7),1000,5,(1,.81,.63));light('cool rim',(-4,-2,6),1400,4,(.44,.62,1));light('front fill',(0,5,3),500,4,(.8,.9,1))
floor=cube('presentation floor',(0,0,-.07),(200,200,.1),mat('stage',(.052,.061,.074),.1,.74),0)
shots=[('rover-front','rover',(4,5,3.2),(0,0,.85),4.0),('rover-rear','rover',(-4,-5,2.9),(0,0,.85),4.0),('signal','signal',(11,13,8),(0,0,3.7),13.4),('rocks','rocks',(4,6,4),(0,0,.3),4.9)]
for name,key,loc,target,ortho in shots:
    if '--skip-render' in sys.argv:continue
    for ak,objects in assets.items():
        for o in objects:o.hide_render=ak!=key
    if key=='rocks':
        for j,o in enumerate(rocks):o.location=((j%3-1)*1.2,(j//3-.5)*1.4,0)
    camera.location=loc;aim(camera,target);camera.data.ortho_scale=ortho
    scene.render.filepath=str(EVID/(name+'.png'));bpy.ops.render.render(write_still=True)
for o in rocks:o.location=(0,0,0)
for ak,objects in assets.items():
    for o in objects:o.hide_render=ak!='rover';o.hide_set(ak!='rover')
camera.location=(4,5,3.2);aim(camera,(0,0,.85));camera.data.ortho_scale=4
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/signal-in-the-dust.blend'))
report['total_triangles']=sum(a['triangles'] for a in report['assets'].values())
report['total_glb_bytes']=sum(a['bytes'] for a in report['assets'].values())
report['script_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
report['blend_sha256']=hashlib.sha256((ROOT/'art-source/signal-in-the-dust.blend').read_bytes()).hexdigest()
(EVID/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert report['total_triangles']<=100000
assert report['total_glb_bytes']<=12*1024*1024
print('ASSET_AUTHORING_COMPLETE',report['total_triangles'],report['total_glb_bytes'])
