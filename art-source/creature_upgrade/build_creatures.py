"""Original creature assets for Signal in the Dust, 2026-09-26.

Run in an owned Blender background process with --factory-startup. Rebuilds only
the creature-art-owned outputs. Coordinates below are Godot metres (Y up).
Aeral reuses the existing authored aeral_showcase.glb without altering its source.
"""
import bpy, bmesh, math, json, hashlib, time
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/visual_fauna'
MICRO = ROOT / 'godot/assets/visual_microfauna'
SOURCE = Path(__file__).resolve().parent
REPORT = ROOT / 'evidence/world-upgrade-20260926/creature-art'
for p in [OUT, MICRO, SOURCE, REPORT]: p.mkdir(parents=True, exist_ok=True)
TAU = math.tau
reports = []

def xyz(p): return (p[0], -p[2], p[1])
def gp(p): return (p[0], p[2], -p[1])
def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name, color, rough=.7, emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
    return m

def mesh(name, verts, faces, mat, parent=None, smooth=True, uvs=None):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(v) for v in verts],[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    if uvs:
        layer=me.uv_layers.new(name='AnatomicalGrowth')
        for poly in me.polygons:
            for loop_index in poly.loop_indices:layer.data[loop_index].uv=uvs[me.loops[loop_index].vertex_index]
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for p in me.polygons:p.use_smooth=smooth
    if parent:ob.parent=parent
    return ob

def empty(name, pos=(0,0,0)):
    ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob);ob.location=xyz(pos);return ob

def loft(name, stations, mat, parent=None, rings=20, ripple=0):
    # Cross sections along z: x/y center, z, x/y radii. Shaped, not scaled spheres.
    verts=[];faces=[]
    for k,(x,y,z,rx,ry) in enumerate(stations):
        for j in range(rings):
            a=j/rings*TAU; f=1+ripple*math.cos(a*5+k*.72)
            verts.append((x+math.cos(a)*rx*f,y+math.sin(a)*ry*f,z))
    for k in range(len(stations)-1):
        for j in range(rings):
            a=k*rings+j;b=k*rings+(j+1)%rings
            faces.append((a,b,b+rings,a+rings))
    faces.extend([tuple(reversed(range(rings))),tuple((len(stations)-1)*rings+j for j in range(rings))])
    return mesh(name,verts,faces,mat,parent)

def tube(name, points, radii, mat, parent=None, sides=10, flatten=1):
    verts=[];faces=[];previous_u=None
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        # Transport one frame along the whole tube. Re-selecting a reference axis
        # at each bend twists corresponding ring vertices and pinches shin tubes.
        if previous_u is None:
            ref=Vector((0,1,0)) if abs(tangent.y)<.92 else Vector((1,0,0))
            u=tangent.cross(ref).normalized()
        else:
            u=(previous_u-tangent*previous_u.dot(tangent)).normalized()
        v=tangent.cross(u).normalized();previous_u=u
        for j in range(sides):
            a=j/sides*TAU;q=Vector(p)+radii[i]*(math.cos(a)*u+math.sin(a)*v*flatten)
            verts.append(tuple(q))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,mat,parent)

def shell(name, center, size, mat, parent=None, yaw=0, ridges=5, scallop=.05):
    # Closed ridged shield. Broad domed top, tapered lip, dark undercut via geometry.
    verts=[];faces=[];uvs=[];n=40;levels=12
    for k in range(levels):
        t=k/(levels-1);r=max(.008,math.sin(t*math.pi/2))
        for j in range(n):
            a=j/n*TAU
            lobed=1+scallop*math.cos(a*ridges)
            x=math.cos(a)*size[0]*r*lobed
            z=math.sin(a)*size[2]*r*(1+.12*math.cos(a))
            y=size[1]*(math.cos(t*math.pi/2)**1.3)+.012*math.cos(a*ridges)*math.sin(t*math.pi)
            verts.append((center[0]+x*math.cos(yaw)-z*math.sin(yaw),center[1]+y,center[2]+x*math.sin(yaw)+z*math.cos(yaw)))
            uvs.append((j/n,t))
    for k in range(levels-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n;faces.append((a,a+n,b+n,b))
    # real thickness at the lip avoids the leaf-like single-sided carapace read
    for j in range(n):
        top=verts[(levels-1)*n+j];verts.append((top[0],top[1]-.075,top[2]))
        uvs.append((j/n,1.0))
    for j in range(n):
        a=(levels-1)*n+j;b=(levels-1)*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(range(n)))
    faces.append(tuple(reversed(range(levels*n,(levels+1)*n))))
    return mesh(name,verts,faces,mat,parent,uvs=uvs)

def petal(name, length, width, curve, mat, parent=None, ruffle=.04):
    # Elongated curved gill/frond with midrib and scalloped trailing silhouette.
    verts=[];faces=[];rows=17;cols=9
    for i in range(rows):
        t=i/(rows-1);profile=(math.sin(math.pi*t)**.65)*(.8+.2*t)+.018
        for j in range(cols):
            u=j/(cols-1)*2-1
            x=u*width*profile
            y=length*t
            z=curve*t*t+.15*width*u*u*math.sin(math.pi*t)+ruffle*math.cos(t*TAU*4)*abs(u)**3*math.sin(math.pi*t)
            verts.append((x,y,z))
    for i in range(rows-1):
        for j in range(cols-1):
            a=i*cols+j;faces.append((a,a+1,a+1+cols,a+cols))
    ob=mesh(name,verts,faces,mat,parent)
    sol=ob.modifiers.new('Organic thin wall','SOLIDIFY');sol.thickness=.018
    return ob

def join_children(parent):
    # One node per moving anatomical part, preserving material surfaces.
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
    if not objs:return
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        bpy.context.view_layer.objects.active=ob;ob.select_set(True)
        for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();ob=objs[0];ob.name=parent.name+'_Geometry'

def export(name, folder=OUT):
    # Vertex transforms in the original Aeral baking invalidate imported custom
    # split normals. Recalculate from the final geometry, including closed scutes.
    for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
        if ob.data.has_custom_normals:
            ob.data.normals_split_custom_set([(0,0,0)]*len(ob.data.loops))
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(ob.data);bm.free();ob.data.update()
    for ob in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
        join_children(ob)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    dest=folder/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True,export_apply=True,
        export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
    b=dest.read_bytes();n=int.from_bytes(b[12:16],'little');j=json.loads(b[20:20+n])
    reports.append({'asset':str(dest.relative_to(ROOT)),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),
        'triangles':sum(j['accessors'][p['indices']]['count']//3 for m in j['meshes'] for p in m['primitives']),
        'meshes':len(j['meshes']),'materials':len(j['materials'])})

def veyra():
    reset();body=empty('Body');skin=material('veyra_skin',(.13,.155,.145),.76)
    stone=material('veyra_mineral',(.29,.31,.255),.85);edge=material('veyra_worn_edge',(.46,.35,.21),.8)
    dark=material('veyra_eyes',(.025,.039,.035),.24);signal=material('veyra_signal',(.67,.28,.07),.52,.2)
    loft('Continuous_muscular_body',[(0,.36,-1.46,.12,.16),(0,.55,-1.2,.52,.34),(0,.64,-.7,.88,.47),(0,.65,0,.99,.52),(0,.58,.8,.8,.42),(0,.43,1.34,.38,.26),(0,.36,1.57,.03,.03)],skin,body,rings=28,ripple=.018)
    # Interlocking dorsal scutes overlap from anterior to posterior, with exposed mineral lips.
    for i in range(6):
        z=-1.02+i*.45;w=[.54,.82,1.03,1.06,.91,.58][i];h=[.29,.42,.49,.48,.39,.24][i]
        shell('Dorsal_scute_%d'%i,(0,.66,z),(w,h,.53),stone,body,ridges=7,scallop=.035)
        for side in [-1,1]:
            shell('Flank_guard',(side*w*.72,.47,z+.08),(.38,.23,.4),stone,body,yaw=side*.28,ridges=4)
            tube('Copper_growth_seam',[(side*w*.18,.68+h*.96,z-.21),(side*w*.48,.68+h*.76,z-.3),(side*w*.8,.7+h*.4,z-.22)], [.014,.021,.009],edge,body,sides=6)
    head=empty('Head',(0,.4,-1.13));head.parent=body
    loft('Sensory_head',[(0,0,-.72,.03,.07),(0,.08,-.52,.3,.2),(0,.12,-.24,.41,.29),(0,.06,.08,.32,.21)],skin,head,rings=20)
    shell('Brow_shield',(0,.18,-.35),(.39,.17,.39),stone,head)
    for side in [-1,1]:
        shell('Inset_eye',(side*.28,.14,-.56),(.075,.058,.12),dark,head)
        tube('Jaw_tusk',[(side*.22,-.08,-.55),(side*.3,-.16,-.73),(side*.21,-.18,-.83)],[.1,.064,.009],edge,head,sides=9)
        tube('Heat_sense',[(side*.32,.15,-.39),(side*.43,.2,-.62),(side*.42,.28,-.9)],[.029,.021,.008],signal,head,sides=7)
        for leg in range(3):
            z=-.77+leg*.77;hip=(side*.78,.47,z);upper=empty('Leg_%s_%d'%('L' if side<0 else 'R',leg),hip)
            tube('Muscular_coxa',[(0,0,0),(side*.23,-.025,.03),(side*.5,-.14,.12)],[.19,.225,.135],skin,upper,sides=12)
            shell('Coxa_guard',(side*.25,.025,.07),(.29,.17,.24),stone,upper,yaw=side*.15)
            lower=empty('Shin_%s_%d'%('L' if side<0 else 'R',leg),(side*.5,-.14,.12));lower.parent=upper
            tube('Tapered_tibia',[(0,0,0),(side*.13,-.23,.055),(side*.09,-.53,.12),(side*.015,-.61,.17)],[.14,.125,.085,.095],stone,lower,sides=12)
            foot=empty('Foot_%s_%d'%('L' if side<0 else 'R',leg),(side*.015,-.61,.17));foot.parent=lower
            # Pads end at y=-.35 relative to the creature's world parent.
            shell('Weight_bearing_pad',(0,-.04,.04),(.17,.08,.24),skin,foot,ridges=3)
            for digit in [-1,0,1]:
                tube('Curved_claw',[(digit*.075,-.045,-.04),(digit*.11,-.062,-.19),(digit*.09,-.07,-.28)],[.044,.035,.005],edge,foot,sides=7)
    export('veyra_runtime')

def morrow():
    reset();body=empty('Body');skin=material('morrow_skin',(.20,.165,.225),.7)
    shellmat=material('morrow_mineral',(.34,.29,.35),.83);lip=material('morrow_worn_edge',(.54,.45,.44),.72)
    membrane=material('morrow_membrane',(.47,.28,.40),.58);signal=material('morrow_signal',(.55,.31,.44),.5,.13)
    dark=material('morrow_eyes',(.046,.022,.057),.3)
    loft('Broad_muscular_foot',[(0,-.52,-1.1,.08,.1),(0,-.51,-.94,.58,.15),(0,-.47,-.52,1.02,.22),(0,-.46,.24,1.16,.23),(0,-.49,.88,.83,.19),(0,-.52,1.13,.18,.11)],skin,body,rings=32,ripple=.036)
    loft('Mantle',[(0,-.23,-.97,.08,.1),(0,-.08,-.76,.57,.43),(0,.03,-.26,.84,.59),(0,-.04,.49,.84,.52),(0,-.19,.95,.42,.28),(0,-.2,1.11,.02,.03)],skin,body,rings=28)
    # Layered shell wraps the mantle; staggered plates provide readable undercuts.
    for i in range(5):
        z=.75-i*.34;w=[.5,.79,.94,.87,.63][i]
        shell('Mantle_scute_%d'%i,(0,.05,z),(w,.36+(1-abs(i-2)/3)*.24,.43),shellmat,body,yaw=.045*(i-2),ridges=9,scallop=.026)
        for side in [-1,1]:
            tube('Shell_growth_lip',[(side*.13,.48,z-.25),(side*w*.56,.37,z-.3),(side*w*.9,.11,z-.21)],[.023,.029,.015],lip,body,sides=7)
    for side in [-1,1]:
        for i in range(7):
            z=-.74+i*.26
            tube('Mantle_cilia',[(side*(.65+.3*math.sin(i/6*math.pi)),-.45,z),(side*(.85+.3*math.sin(i/6*math.pi)),-.62,z-.055),(side*(.9+.3*math.sin(i/6*math.pi)),-.68,z-.1)],[.054,.04,.01],lip,body,sides=7)
        tube('Sensory_feeler',[(side*.37,-.18,-.8),(side*.56,-.09,-1.09),(side*.65,.12,-1.32),(side*.56,.23,-1.4)],[.082,.06,.034,.012],skin,body,sides=9)
        shell('Eye_node',(side*.56,.2,-1.4),(.057,.055,.065),dark,body)
    crown=empty('Crown',(0,.36,.13));crown.parent=body
    # Living gills form a crown, growing from the shell opening rather than straight rods.
    for i in range(7):
        a=i/7*TAU;root=(math.cos(a)*.21,.0,math.sin(a)*.21)
        frond=empty('CrownFrond_%d'%i,root);frond.parent=crown
        frond.rotation_euler.z=-a # y-up yaw expressed around Blender Z
        length=1.13+.14*math.sin(i*2.1);width=.22+.035*(i%3)
        petal('Sensory_gill',length,width,.57,membrane,frond)
        tube('Midrib',[(0,0,0),(0,length*.32,.05),(0,length*.66,.26),(0,length,.57)],[.044,.035,.025,.006],lip,frond,sides=7)
        for row in range(1,7):
            t=row/8;profile=math.sin(math.pi*t)**.65
            for side in [-1,1]:
                tube('Gill_lamella',[(0,length*t,.57*t*t),(side*width*.52*profile,length*(t+.05),.57*(t+.05)**2),(side*width*profile,length*(t+.025),.57*(t+.025)**2+.025)], [.012,.016,.004],signal,frond,sides=5)
    export('morrow_runtime')

def micro():
    reset();body=empty('Body');skin=material('micro_skin',(.18,.255,.23),.65)
    membrane=material('micro_membrane',(.39,.53,.44),.57);signal=material('micro_signal',(.61,.39,.2),.5,.13)
    loft('Thorax',[(0,0,-.27,.025,.025),(0,.01,-.12,.064,.06),(0,0,.08,.045,.046),(0,0,.24,.008,.012)],skin,body,rings=12)
    for side in [-1,1]:
        wing=empty('Wing_L' if side<0 else 'Wing_R',(side*.035,.02,-.05))
        verts=[];faces=[]
        for i in range(15):
            t=i/14
            for j in range(7):
                u=j/6;span=.42*math.sin(t*math.pi/2)
                verts.append((side*span,.04*math.sin(u*math.pi)*math.sin(t*math.pi),-.09*t+(.34*math.sin(t*math.pi)**.7+.01)*(u-.4)))
        for i in range(14):
            for j in range(6):
                a=i*7+j;faces.append((a,a+7,a+8,a+1))
        mesh('Scalloped_wing',verts,faces,membrane,wing)
        tube('Wing_vein',[(0,0,0),(side*.18,.012,-.02),(side*.35,.01,-.055),(side*.42,0,-.09)],[.009,.007,.006,.003],skin,wing,sides=5)
        tube('Antenna',[(side*.025,.025,-.19),(side*.055,.08,-.28),(side*.06,.10,-.32)],[.007,.004,.001],signal,body,sides=5)
        for j in range(3):
            z=-.09+j*.075
            tube('Landing_tarsus',[(side*.04,-.005,z),(side*.09,-.025,z-.015),(side*.085,-.08,z-.055)],[.006,.005,.002],skin,body,sides=5)
    export('shore_flier',MICRO)
    reset();body=empty('Body');skin=material('micro_skin',(.17,.21,.19),.78)
    shellmat=material('micro_mineral',(.37,.33,.23),.84);signal=material('micro_signal',(.45,.28,.11),.61,.04)
    for i in range(5):shell('Back_segment',(0,.095,-.18+i*.09),(.12+.02*math.sin(i),.055,.075),shellmat,body,ridges=5)
    for side in [-1,1]:
        for i in range(4):
            z=-.14+i*.095
            paddle=empty('Paddle_%s_%d'%('L' if side<0 else 'R',i),(side*.07,.09,z))
            tube('Jointed_paddle',[(0,0,0),(side*.11,-.05,.02),(side*.13,-.078,-.02)],[.014,.012,.003],skin,paddle,sides=6)
        tube('Feeler',[(side*.05,.1,-.21),(side*.11,.15,-.29),(side*.15,.12,-.36)],[.012,.007,.001],signal,body,sides=6)
    export('shore_crawler',MICRO)

def aeral():
    reset();source=OUT/'aeral_showcase.glb';source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.import_scene.gltf(filepath=str(source))
    dg=bpy.context.evaluated_depsgraph_get();parts=[];all_points=[]
    for ob in list(bpy.context.scene.objects):
        if ob.type!='MESH' or 'perch_support' in ob.name:continue
        if ob.data.shape_keys:
            for key in list(ob.data.shape_keys.key_blocks)[1:]:key.value=1
    bpy.context.view_layer.update()
    for ob in list(bpy.context.scene.objects):
        if ob.type!='MESH' or 'perch_support' in ob.name:continue
        ancestor=ob;group='Body'
        while ancestor:
            if 'MainWing_L' in ancestor.name:group='Wing_L';break
            if 'MainWing_R' in ancestor.name:group='Wing_R';break
            ancestor=ancestor.parent
        if any(label in ob.name for label in ['claw','toe','landing_leg','grasping_digit']):
            coords=[gp(ob.matrix_world @ v.co) for v in ob.data.vertices]
            group='LandingLeg_L' if sum(v[0] for v in coords)/len(coords)<0 else 'LandingLeg_R'
        evaluated=ob.evaluated_get(dg);me=bpy.data.meshes.new_from_object(evaluated,depsgraph=dg)
        points=[gp(ob.matrix_world@v.co) for v in me.vertices];all_points+=points
        parts.append((ob,group,me,points))
    lo=[min(p[i] for p in all_points) for i in range(3)];hi=[max(p[i] for p in all_points) for i in range(3)]
    size=5.6/(hi[0]-lo[0]);center=Vector(((hi[0]+lo[0])*.5,(hi[1]+lo[1])*.5,(hi[2]+lo[2])*.5))
    pivots={'Body':Vector((0,3.2,0)),'Wing_L':Vector((-.75,3.5,-.4)),'Wing_R':Vector((.75,3.5,-.4)),
        'LandingLeg_L':Vector((-.45,2.6,.25)),'LandingLeg_R':Vector((.45,2.6,.25))}
    nodes={key:empty(key,tuple((pivot-center)*size)) for key,pivot in pivots.items()}
    original=list(bpy.context.scene.objects)
    for ob,group,me,points in parts:
        clone=bpy.data.objects.new('Runtime_'+ob.name,me);bpy.context.collection.objects.link(clone);clone.parent=nodes[group]
        for v,p in zip(me.vertices,points):v.co=xyz((Vector(p)-pivots[group])*size)
        # Geometry already contains authored large forms. Decimation removes unseen tessellation.
        if len(me.polygons)>1500:
            bpy.context.view_layer.objects.active=clone;clone.select_set(True)
            mod=clone.modifiers.new('Runtime surface economy','DECIMATE');mod.ratio=.38
            bpy.ops.object.modifier_apply(modifier=mod.name);clone.select_set(False)
    for ob in original:
        if ob not in nodes.values():bpy.data.objects.remove(ob,do_unlink=True)
    export('aeral_runtime')
    reports[-1].update({'derived_from':'godot/assets/visual_fauna/aeral_showcase.glb','sourceSha256':source_hash,
        'sourceBounds':{'min':lo,'max':hi},'scale':size,'sourceCenter':list(center),'wingspanMetres':5.6,
        'morphs':'existing authored morphs baked at 1.0; unchanged source retained'})

veyra();morrow();micro();aeral()
(REPORT/'asset-provenance.json').write_text(json.dumps({'date':'2026-09-26','blender':bpy.app.version_string,
    'author':'Codex creature-art, project-original procedural meshes','license':'Project-authored; no external downloaded assets',
    'rebuild':str(Path(__file__).relative_to(ROOT)),'outputs':reports},indent=2),encoding='utf-8')
print('CREATURE_ASSETS_COMPLETE '+json.dumps(reports))
