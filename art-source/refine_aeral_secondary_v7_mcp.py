"""Bounded secondary form pass: broaden wing fans and define cranio-gular organs.
Preserve accepted v6 body, shoulders, hip proportions, feet and perch unchanged.
"""
import bpy
import math
import runpy
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
assert bpy.data.filepath.endswith('aeral-mcp-forms-v6.blend'), bpy.data.filepath
assert bpy.context.mode=='OBJECT'
h=runpy.run_path(str(ROOT/'art-source/build_visual_fauna.py'),run_name='shape_utilities')
tube=h['tube'];spline=h['spline'];mesh_object=h['mesh_object']
root=bpy.data.objects['FormV6_Aeral']
body=bpy.data.objects['FormV6_continuous_head_chest']
skin=body.data.materials[0]
hard=bpy.data.objects['FormV6_integrated_cranial_hood'].data.materials[0]
membrane=bpy.data.objects['FormV6_tension_membrane'].data.materials[0]

# Snapshot accepted anatomy topology/coordinates for exact preservation checks.
kept=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('FormV6_') and any(k in o.name for k in ('head_chest','landing_leg','grasping','claw','perch_support'))]
def digest(obj):
    return hashlib.sha256(repr([tuple(v.co) for v in obj.data.vertices]).encode()).hexdigest()
before={obj.name:digest(obj) for obj in kept}

def sample(points,s):
    curve=spline(points,20)
    f=s*(len(curve)-1);i=min(int(f),len(curve)-2)
    return Vector(curve[i]).lerp(Vector(curve[i+1]),f-i)

def wing_point(s,t,side,fold):
    # Root/arm/wrist locations remain v6; the crown fans broadly beyond the wrist.
    leading=sample([(1.4,.72,4.12),(2.35,1.07,4.88),(3.4,1.08,7.9),
                    (4.8,.74,8.48),(6.24,.10,8.0),(7.15,-.85,6.6)],s)
    trailing=sample([(.72,-.8,2.9),(1.4,-1.95,2.66),(2.9,-3.65,2.45),
                     (5.1,-4.48,2.87),(6.8,-3.48,4.2),(7.15,-.85,6.6)],s)
    # Cosine hollows have continuous tangents, removing v6's pointed stair steps.
    lobe=(1-math.cos(s*math.tau*4))*.5
    envelope=math.sin(math.pi*s)**.65
    trailing.y+=.42*lobe*envelope
    trailing.z+=.22*lobe*envelope
    p=leading.lerp(trailing,t)
    p.z+=.36*math.sin(math.pi*t)*math.sin(math.pi*s)
    hinge=Vector((2.35,1.07,4.88))
    weight=max(0,min(1,(s-.15)/.10));weight=weight*weight*(3-2*weight)
    folded=hinge+Matrix.Rotation(-fold*1.25,3,'Z') @ (Matrix.Rotation(fold*.42,3,'Y') @ (p-hinge))
    p=p.lerp(folded,weight);p.x*=side
    return p

hidden=[]
for side,fold,label in [(-1,0,'L'),(1,.70,'R')]:
    parent=bpy.data.objects['FormV6_MainWing_'+label]
    for obj in list(parent.children):
        obj.hide_render=True;obj.hide_set(True);hidden.append(obj.name)
    ns,nt=97,33
    vertices=[];faces=[];uvs=[]
    for i in range(ns):
        for j in range(nt):
            s=i/(ns-1);t=j/(nt-1)
            vertices.append(tuple(wing_point(s,t,side,fold)));uvs.append((s,t))
    for i in range(ns-1):
        for j in range(nt-1):
            a=i*nt+j;b=a+nt
            faces.append((a,a+1,b+1,b) if side>0 else (a,b,b+1,a+1))
    obj=mesh_object('FormV7_broad_fan_'+label,vertices,faces,membrane,uvs,parent)
    modifier=obj.modifiers.new('Membrane thickness','SOLIDIFY');modifier.thickness=.018
    pts=[tuple(wing_point(i/80,0,side,fold)) for i in range(81)]
    tube('FormV7_arm_wrist_crown_'+label,pts,[.18*(1-i/80)**.8+.01 for i in range(81)],hard,14,parent)
    for number,end in enumerate([.16,.28,.40,.52,.64,.76,.88,.96]):
        pts=[]
        for j in range(33):
            t=j/32;s=max(0,end-.09*(1-t))
            p=wing_point(s,t,side,fold);p.z+=.025
            pts.append(tuple(p))
        tube('FormV7_arc_finger_'+label+'_'+str(number),pts,[.06*(1-j/32)**.8+.006 for j in range(33)],hard,9,parent)
    pts=[tuple(wing_point(i/96,1,side,fold)) for i in range(97)]
    tube('FormV7_rounded_rear_margin_'+label,pts,[.022]*97,skin,7,parent)

# A hard dorsal head shield with a broad front edge, not a closed pipe at the nose.
oldhood=bpy.data.objects['FormV6_integrated_cranial_hood'];oldhood.hide_render=True;oldhood.hide_set(True);hidden.append(oldhood.name)
vertices=[];faces=[];nu,nv=37,25
for i in range(nu):
    u=i/(nu-1)
    width=.38+.43*math.sin(math.pi*u)-.12*u
    top=3.79-.48*u+.17*math.sin(math.pi*u)
    for j in range(nv):
        v=j/(nv-1)*2-1
        vertices.append((v*width,1.12+1.51*u,top-.25*v*v-.025*math.sin(v*math.pi)**2))
for i in range(nu-1):
    for j in range(nv-1):
        a=i*nv+j;faces.append((a,a+nv,a+nv+1,a+1))
hood=mesh_object('FormV7_cranial_shield',vertices,faces,hard,parent=root)
solid=hood.modifiers.new('Shield thick edge','SOLIDIFY');solid.thickness=.065
bevel=hood.modifiers.new('Organic softened lip','BEVEL');bevel.width=.02;bevel.segments=2

# Mouth is a transverse soft rim beneath the shield. Both ends blend into cheeks.
for lower in (False,True):
    pts=[]
    for i in range(37):
        a=i/36*math.pi
        pts.append((-.62*math.cos(a),1.95+.65*math.sin(a),3.11-.16*math.sin(a)-(.065 if lower else 0)))
    tube('FormV7_soft_mouth_rim',pts,[.024+.018*math.sin(i/36*math.pi) for i in range(37)],skin,10,root)

# Main throat lamellae follow the actual fused body's surface via local ray queries.
# Attached half-elliptical folds express organs, not detached rods or microtexture.
folds=0
for column in range(7):
    center=(column-3)*.125
    vertices=[];faces=[];rings,sides=31,12
    valid=True
    for i in range(rings):
        t=i/(rings-1);z=2.93-.78*t
        x=center*(.72+.28*math.sin(math.pi*t))
        hit,location,normal,_=body.ray_cast(Vector((x,6,z)),Vector((0,-1,0)))
        if not hit:valid=False;break
        width=(.035+.012*math.sin(math.pi*t))*(.45+.55*math.sin(math.pi*t))
        depth=.018+.055*math.sin(math.pi*t)
        for j in range(sides):
            a=j/sides*math.tau
            vertices.append((x+width*math.cos(a),location.y+.004+depth*math.sin(a),z))
    if not valid:continue
    for i in range(rings-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    mesh_object('FormV7_gular_lamella_'+str(column),vertices,faces,skin,parent=root);folds+=1

assert all(digest(obj)==before[obj.name] for obj in kept)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/visual_fauna/aeral-mcp-secondary-v7.blend'))
result={'kind':'bounded secondary sculpture, untextured/unlit-emission','file':bpy.data.filepath,'preservedAnatomy':before,'hiddenV6ReferenceObjects':hidden,'gularFolds':folds,'next':'same camera comparison of wing fan and head/throat organs','productionAccepted':False}
