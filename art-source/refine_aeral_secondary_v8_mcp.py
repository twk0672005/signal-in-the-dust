"""Self-inspection repair: replace wire-like throat lamellae with one pleated organ."""
import bpy
import math
import runpy
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
assert bpy.data.filepath.endswith('aeral-mcp-secondary-v7.blend'), bpy.data.filepath
assert bpy.context.mode=='OBJECT'
h=runpy.run_path(str(ROOT/'art-source/build_visual_fauna.py'),run_name='geometry_utilities')
body=bpy.data.objects['FormV6_continuous_head_chest'];parent=bpy.data.objects['FormV6_Aeral'];skin=body.data.materials[0]
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith('FormV7_gular_lamella_'):
        obj.hide_render=True;obj.hide_set(True)
vertices=[];faces=[];uvs=[];rows,columns=41,49
for i in range(rows):
    t=i/(rows-1);z=2.98-.88*t
    width=.51*(.87+.13*math.sin(math.pi*t))*(1-.16*t)
    for j in range(columns):
        v=j/(columns-1)*2-1;x=width*v
        hit,location,normal,_=body.ray_cast(Vector((x,6,z)),Vector((0,-1,0)))
        assert hit, (i,j,x,z)
        pleat=(.5+.5*math.cos(v*math.pi*4+.28*math.sin(t*math.pi)))**3
        edge=max(0,1-v*v)**.7
        rise=(.02+.105*pleat)*math.sin(math.pi*t)**.5*edge
        vertices.append((x,location.y+.009+rise,z));uvs.append((j/(columns-1),t))
for i in range(rows-1):
    for j in range(columns-1):
        a=i*columns+j;b=a+columns;faces.append((a,a+1,b+1,b))
organ=h['mesh_object']('FormV8_continuous_pleated_gular_organ',vertices,faces,skin,uvs,parent)
solid=organ.modifiers.new('Soft tissue thickness','SOLIDIFY');solid.thickness=.018

# The primary fan from v7 stays intact. Recurve only its ribs to follow tension arcs.
source=(ROOT/'art-source/refine_aeral_secondary_v7_mcp.py').read_text(encoding='utf-8')
import ast
module=ast.parse(source)
functions=ast.Module(body=[node for node in module.body if isinstance(node,ast.FunctionDef) and node.name in ('sample','wing_point')],type_ignores=[])
scope={'Vector':Vector,'Matrix':Matrix,'math':math,'spline':h['spline']}
exec(compile(functions,'v7-wing-functions','exec'),scope)
wing_point=scope['wing_point']
for side,fold,label in [(-1,0,'L'),(1,.70,'R')]:
    wing=bpy.data.objects['FormV6_MainWing_'+label]
    old=[obj for obj in wing.children if obj.name.startswith('FormV7_arc_finger_')]
    hard=old[0].data.materials[0]
    for obj in old:obj.hide_render=True;obj.hide_set(True)
    for number,end in enumerate([.16,.28,.40,.52,.64,.76,.88,.96]):
        pts=[]
        for j in range(41):
            t=j/40
            s=max(0,min(1,end-.09*(1-t)+.065*math.sin(math.pi*t)))
            p=wing_point(s,t,side,fold);p.z+=.027;pts.append(tuple(p))
        radius=.061 if number%2==0 else .036
        h['tube']('FormV8_tension_arc_'+label+'_'+str(number),pts,[radius*(1-j/40)**.8+.005 for j in range(41)],hard,9,wing)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/visual_fauna/aeral-mcp-secondary-v8.blend'))
result={'kind':'secondary organ/fan candidate, no microdetail/PBR/emission','file':bpy.data.filepath,'gularOrgan':'single attached continuous pleated surface','wingFanGeometry':'unchanged from v7, only ribs recurved','preserved':'v6 body/shoulders/hips/feet/perch and v7 fan outline','accepted':False}
