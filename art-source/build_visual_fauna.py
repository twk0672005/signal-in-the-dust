"""Original authored fauna. Blender 5.2.1, metres, X right/Y forward/Z up.
Production meshes use shaped surfaces, connected anatomical volumes and local PBR maps.
Run --background --factory-startup --python this-file -- --species aeral
"""
import bpy
import math
import random
import json
import hashlib
import sys
import argparse
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/visual_fauna'
SOURCE = ROOT / 'art-source/visual_fauna'
EVID = ROOT / 'evidence/visual-upgrade-20260923/fauna-authoring'
for directory in (OUT, SOURCE, EVID): directory.mkdir(parents=True, exist_ok=True)
random.seed(230926)
TAU = math.tau

def mesh_object(name, vertices, faces, material, uvs=None, parent=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material: mesh.materials.append(material)
    if parent: obj.parent = parent
    layer = mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices:
            idx = mesh.loops[loop].vertex_index
            p = vertices[idx]
            layer.data[loop].uv = uvs[idx] if uvs else (p[0] * .32, p[1] * .32 + p[2] * .12)
    return obj

def empty(name, loc=(0,0,0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.parent = parent
    return obj

def pbr(name, color, roughness, style='skin', alpha=1, emission=0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*color, alpha)
    material.use_backface_culling = False
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Alpha'].default_value = alpha
    shader.inputs['Metallic'].default_value = .08 if style == 'mineral' else 0
    if alpha < 1: material.surface_render_method = 'DITHERED'
    if emission:
        shader.inputs['Emission Color'].default_value = (*color,1)
        shader.inputs['Emission Strength'].default_value = emission
    n = 512
    y,x = np.mgrid[0:n,0:n].astype(np.float32) / n
    rng = np.random.default_rng(230926 + len(name))
    grain = rng.random((n,n)).astype(np.float32)
    waves = (.5 + .22*np.sin(x*23+np.sin(y*17)*2) + .15*np.sin(y*53+x*11)
             + .08*np.sin(x*181+y*93) + .05*grain)
    if style == 'membrane':
        branches = np.exp(-np.abs(np.sin(x*TAU*13+np.sin(y*TAU*3)*.8))*23)
        cells = np.exp(-np.abs(np.sin(y*TAU*21+x*TAU*9))*24)
        h = .18*waves + .5*branches + .12*cells
    elif style == 'mineral':
        strata = np.sin(y*TAU*17+np.sin(x*TAU*2)*1.7)
        pores = (grain > .92).astype(np.float32)
        h = .3*waves + .2*strata - .25*pores
    else:
        folds = np.sin(x*TAU*22+np.sin(y*TAU*4)*2)
        h = .2*waves + .12*folds + .05*grain
    dy,dx = np.gradient(h)
    normal = np.stack((-dx*8,-dy*8,np.ones_like(h)),axis=-1)
    normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
    for suffix, pixels, noncolor in [
        ('normal', np.concatenate((normal*.5+.5,np.ones((n,n,1))),axis=-1),True),
        ('color',np.concatenate((np.stack([np.clip(c*(.66+.5*waves+.12*h),0,1) for c in color],axis=-1),np.ones((n,n,1))),axis=-1),False),
        ('rough',np.stack([np.clip(roughness+.16*(waves-.5),.08,.98)]*3+[np.ones_like(h)],axis=-1),True)]:
        img=bpy.data.images.new(name+'_'+suffix,width=n,height=n,alpha=True)
        if noncolor: img.colorspace_settings.name='Non-Color'
        img.pixels.foreach_set(pixels.astype(np.float32).ravel())
        img.filepath_raw=str(OUT/(name+'_'+suffix+'.png'))
        img.file_format='PNG'; img.save(); img.pack()
        tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
        if suffix=='normal':
            nm=material.node_tree.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=.5
            material.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color'])
            material.node_tree.links.new(nm.outputs['Normal'],shader.inputs['Normal'])
        else:
            if suffix == 'rough': shader.inputs['Roughness'].default_value=1.0
            material.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color' if suffix=='color' else 'Roughness'])
    return material

def tube(name, points, radii, material, sides=10, parent=None):
    vertices,faces,uvs=[],[],[]
    pts=[Vector(p) for p in points]
    previous_u = None
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        if previous_u is None:
            reference=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
            u=tangent.cross(reference).normalized()
        else:
            # Parallel-transport the section basis: choosing a new world axis at
            # every ring makes curved knees/ribs twist and tear at the threshold.
            u=(previous_u-tangent*previous_u.dot(tangent)).normalized()
        v=tangent.cross(u).normalized()
        previous_u=u
        radius=radii[i] if isinstance(radii,list) else radii
        for j in range(sides):
            angle=j/sides*TAU
            q=p+(u*math.cos(angle)+v*math.sin(angle))*radius
            vertices.append(tuple(q));uvs.append((j/sides,i/(len(pts)-1)))
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
    return mesh_object(name,vertices,faces,material,uvs,parent)

def spline(points, steps=6):
    points=[Vector(p) for p in points]; out=[]
    for i in range(len(points)-1):
        a,b,c,d=points[max(i-1,0)],points[i],points[i+1],points[min(i+2,len(points)-1)]
        for k in range(steps):
            t=k/steps
            out.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
    return out+[tuple(points[-1])]

def organic_tube(name, points, radius, material, parent=None, sides=10):
    pts=spline(points,5)
    radii=[radius*(1-.82*i/(len(pts)-1)) for i in range(len(pts))]
    return tube(name,pts,radii,material,sides,parent)

def loft(name, sections, material, sides=40, subdivisions=4, parent=None):
    # Each section: forward y, centre z, lateral radius, vertical radius.
    profiles=[]
    for i in range(len(sections)-1):
        a=np.array(sections[max(0,i-1)]);b=np.array(sections[i]);c=np.array(sections[i+1]);d=np.array(sections[min(len(sections)-1,i+2)])
        for k in range(subdivisions):
            t=k/subdivisions
            profiles.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    profiles.append(np.array(sections[-1]))
    vertices,faces,uvs=[],[],[]
    for i,(y,z,rx,rz) in enumerate(profiles):
        for j in range(sides):
            a=j/sides*TAU
            organic=1+.016*math.sin(a*7+i*.63)+.012*math.cos(a*11-i*.37)
            vertices.append((max(.008,rx)*math.cos(a)*organic,y,z+max(.008,rz)*math.sin(a)*organic))
            uvs.append((j/sides,i/(len(profiles)-1)))
    for i in range(len(profiles)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,a+sides,b+sides,b))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(profiles)-1)*sides+j for j in range(sides)))
    return mesh_object(name,vertices,faces,material,uvs,parent)

def plate(name, center, scale, material, seed, parent=None):
    # Layered keeled scute: irregular complete underside and worn thick outer lip.
    rng=random.Random(seed); vertices=[];rings=6;sides=13
    for r in range(rings):
        t=r/(rings-1)
        for j in range(sides):
            a=j/sides*TAU
            edge=1+.08*math.sin(j*2.7+seed)+.04*rng.uniform(-1,1)
            x=math.cos(a)*scale[0]*t*edge
            y=math.sin(a)*scale[1]*t*edge
            z=scale[2]*(1-t*t)*(.8+.2*math.cos(a*2))+.045*math.sin(t*29+a*3)
            vertices.append((center[0]+x,center[1]+y,center[2]+z))
    faces=[]
    for r in range(rings-1):
        for j in range(sides):
            a=r*sides+j;b=r*sides+(j+1)%sides
            faces.append((a,a+sides,b+sides,b))
    lower=len(vertices)
    for j in range(sides):
        p=vertices[(rings-1)*sides+j];vertices.append((p[0],p[1],p[2]-.1))
    for j in range(sides):
        a=(rings-1)*sides+j;b=(rings-1)*sides+(j+1)%sides
        faces.append((a,lower+j,lower+(j+1)%sides,b))
    faces.append(tuple(lower+j for j in reversed(range(sides))))
    return mesh_object(name,vertices,faces,material,parent=parent)

def eye(name, loc, size, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc)
    obj=bpy.context.object;obj.name=name;obj.scale=size;obj.data.materials.append(material);obj.parent=parent
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def join_material_groups(parent):
    # Keep animated anatomical nodes separate; batch static parts per material/parent.
    groups={}
    for obj in list(bpy.context.scene.objects):
        if obj.type=='MESH':groups.setdefault((obj.parent,obj.data.materials[0]),[]).append(obj)
    for (owner,mat),parts in groups.items():
        if len(parts)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join();parts[0].name=owner.name+'_'+mat.name if owner else mat.name

def build_aeral():
    root=empty('Aeral')
    skin=pbr('aeral_indigo_skin',(.085,.07,.145),.47)
    armour=pbr('aeral_rib_ceramic',(.23,.17,.225),.43,'mineral')
    membrane=pbr('aeral_smoke_membrane',(.24,.20,.32),.59,'membrane',.94)
    throat=pbr('aeral_throat_folds',(.34,.18,.075),.58,emission=.06)
    dark=pbr('aeral_sensory_glass',(.018,.024,.042),.13)
    glow=pbr('aeral_cyan_nodes',(.04,.55,.82),.26,emission=2)
    body=empty('BreathingBody',parent=root)
    loft('Thoracic volume',[(-2.2,2.65,.08,.07),(-1.55,2.8,.46,.4),(-.5,2.9,.88,.84),(.55,3.05,.82,.88),(1.25,3.18,.48,.55),(1.55,3.2,.18,.25)],skin,parent=body)
    loft('Sensory wedge',[(1.10,3.2,.34,.37),(1.65,3.22,.54,.47),(2.12,3.13,.35,.32),(2.42,3.05,.10,.10)],armour,parent=body)
    for row in range(9):
        y=-1.35+row*.32
        breadth=.7*math.sin((row+1)/11*math.pi)
        top=3.48+.43*math.sin((row+1)/11*math.pi)
        for column in [-1,0,1]:
            plate('Thoracic overlapping scute',(column*breadth*.65,y,top-.15*abs(column)),(.30,.32,.11),armour,230+row*3+column,body)
    for side in (-1,1):
        eye('Recessed eye',(side*.435,1.88,3.37),(.11,.17,.105),dark,body)
        organic_tube('Brow rim',[(side*.28,2.17,3.46),(side*.48,1.98,3.53),(side*.51,1.65,3.5)],.085,armour,body)
        for row in range(4):
            for col in range(3):
                plate('Cheek scute',(side*(.36+col*.09),.7-row*.42,3.45-col*.13),(.22,.30,.09),armour,30+row*3+col,body)
        for j in range(12):
            y=1.6-j*.17
            organic_tube('Breathing gill',[(side*.35,y,2.84),(side*.52,y-.04,2.49),(side*.22,y-.10,2.24+.08*math.sin(j))],.082,throat,body)
        for j in range(6):
            organic_tube('Feeding fringe',[(side*(.06+j*.042),2.29,2.98),(side*(.10+j*.065),2.36,2.70-j*.024),(side*(.14+j*.07),2.18,2.61-j*.025)],.022,skin,body,7)
        for j in range(5):
            eye('Signal organ',(side*(.52+.06*math.sin(j)),.15+j*.21,3.41),(.04,.07,.035),glow,body)
        leg=empty('LandingLeg_'+('L' if side<0 else 'R'),parent=root)
        tube('Articulated landing limb',spline([(side*.51,.12,2.6),(side*.94,-.15,1.55),(side*.62,.57,.64),(side*.65,.7,.25)],5),[.34*(1-.60*i/15) for i in range(16)],skin,20,leg)
        for toe in range(3):
            x=side*.65+(toe-1)*.16
            organic_tube('Grasping digit',[(side*.65,.7,.3),(x,1.03,.10),(x,1.3,.03),(x,1.40,.12)],.065,armour,leg)
        wing=empty('Wing_'+('L' if side<0 else 'R'),(side*.68,.15,3.25),root)
        edge=spline([(0,.4,0),(side*1.8,.9,1.95),(side*4.5,.35,3.0),(side*6.25,-1.4,2.3),(side*4.2,-3.7,.38),(side*.55,-2.35,-.48)],8)
        shoulder=Vector((0,0,0)); vertices=[];faces=[];uvs=[];radial=14
        for j,end in enumerate(edge):
            p=Vector(end)
            for k in range(radial+1):
                t=k/radial;q=shoulder.lerp(p,t)
                q.z += .08*math.sin(t*math.pi)*math.sin(j*.78)
                vertices.append(tuple(q));uvs.append((j/(len(edge)-1),t))
        for j in range(len(edge)-1):
            for k in range(radial):
                a=j*(radial+1)+k;b=a+radial+1
                faces.append((a,b,b+1,a+1) if side>0 else (a,a+1,b+1,b))
        wing_surface=mesh_object('Veined primary membrane',vertices,faces,membrane,uvs,wing)
        # The tailward root section is a single connected fan, not overlapping fins.
        tube('Leading load edge',edge,[.12*(1-.74*i/(len(edge)-1)) for i in range(len(edge))],armour,12,wing)
        for rib in range(1,14):
            idx=round(rib/14*(len(edge)-1));end=Vector(edge[idx])
            points=[tuple(end*t+Vector((0,0,.12+.06*math.sin(t*math.pi)))) for t in [0,.2,.45,.72,1]]
            organic_tube('Branching wing rib',points,.06,armour,wing,8)
            for branch in [.4,.65,.82]:
                a=end*branch;other=Vector(edge[min(idx+2,len(edge)-1)])*(branch+.08)
                organic_tube('Membrane fiber',[tuple(a),tuple((a+other)*.5+Vector((0,0,.018))),tuple(other)],.012,throat,wing,5)
        # No extra shoulder wing pair: a single narrow tail-root stabilizer below.
    tail=empty('TailStabilizer',(0,-1.7,2.66),root)
    vertices=[(0,0,0),(-.75,-1.0,-.12),(0,-1.65,-.24),(.75,-1.0,-.12)]
    mesh_object('Single caudal stabilizer',vertices,[(0,1,2),(0,2,3)],membrane,parent=tail)
    for p in vertices[1:]:organic_tube('Caudal rib',[(0,0,0),tuple(Vector(p)*.5),p],.03,armour,tail)
    join_material_groups(root)
    return root

def export_asset(kind, root):
    bpy.context.view_layer.update()
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC'
    scene.render.fps=30
    scene.frame_start=1;scene.frame_end=90
    blend=SOURCE/(kind+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    glb=OUT/(kind+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_animations=False,export_yup=True)
    vertices=[];triangles=0
    for obj in scene.objects:
        if obj.type!='MESH':continue
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        vertices.extend([obj.matrix_world@Vector(v) for v in obj.bound_box])
    data=glb.read_bytes();length=int.from_bytes(data[12:16],'little');doc=json.loads(data[20:20+length])
    report={'species':kind,'kind':'authored_candidate_pending_Godot_visual_review','blender':bpy.app.version_string,
      'sourceScript':str(Path(__file__).relative_to(ROOT)),'sourceScriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
      'glb':str(glb.relative_to(ROOT)),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'triangles':triangles,
      'boundsBlender':{'min':[min(p[i] for p in vertices) for i in range(3)],'max':[max(p[i] for p in vertices) for i in range(3)]},
      'nodes':[n.get('name') for n in doc.get('nodes',[])],'materials':[{'name':m.get('name'),'alphaMode':m.get('alphaMode','OPAQUE')} for m in doc.get('materials',[])],
      'license':'Original local geometry and synthesized PBR textures; concepts used as approved design references only',
      'motionOwner':'Godot anatomical-node controller; no baked skeleton animation in this candidate',
      'aeralTopology':'Exactly one shoulder-born primary wing pair; one separate narrow tail-root stabilizer. Side/rear in-engine inspection required.'}
    (EVID/(kind+'-manifest.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('FAUNA_EXPORT '+json.dumps({k:report[k] for k in ('species','bytes','triangles','sha256')}))

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser();parser.add_argument('--species',default='aeral',choices=['aeral'])
    config=parser.parse_args(args)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    export_asset(config.species,build_aeral())
