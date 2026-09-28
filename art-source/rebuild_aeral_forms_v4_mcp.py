"""Live Blender MCP primary-form rebuild. Deliberately no texture or glow pass.
Runs in the dedicated Blender scene; rejected v1/v2 source files remain untouched.
"""
import bpy
import math
import runpy
from pathlib import Path
from mathutils import Vector

ROOT=Path('C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923')
OUT=ROOT/'evidence/visual-upgrade-20260923/aeral-mcp-forms-v4'
OUT.mkdir(parents=True,exist_ok=True)
helpers=runpy.run_path(str(ROOT/'art-source/build_visual_fauna.py'),run_name='fauna_geometry_helpers')
loft=helpers['loft'];tube=helpers['tube'];spline=helpers['spline'];mesh_object=helpers['mesh_object'];plate=helpers['plate'];empty=helpers['empty']

# Preserve the rejected geometry in a hidden collection inside the new working file.
old=bpy.context.scene.collection.children.get('Rejected_Aeral_v3')
if old is None:
    old=bpy.data.collections.new('Rejected_Aeral_v3');bpy.context.scene.collection.children.link(old)
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith('FormV4_'):continue
    for collection in list(obj.users_collection):collection.objects.unlink(obj)
    old.objects.link(obj)
old.hide_render=True;old.hide_viewport=True

def clay(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.7
    return m

skin=clay('FormV4 warm grey skin',(.37,.40,.43))
hard=clay('FormV4 mineral support',(.44,.46,.47))
membrane=clay('FormV4 membrane clay',(.48,.50,.52))
eye_mat=clay('FormV4 inset eyes',(.075,.09,.10))
root=empty('FormV4_Aeral')

# One continuous cranio-thoracic skin: deep sternum, lifted shoulder, tapering abdomen.
body=loft('FormV4_continuous_head_chest',[
    (-3.0,2.12,.045,.05),(-2.25,2.22,.33,.27),(-1.5,2.38,.69,.53),
    (-.65,2.58,.91,.83),(.15,2.75,1.04,1.13),(.8,2.98,.91,1.08),
    (1.35,3.04,.72,.83),(1.80,3.16,.69,.53),(2.22,3.14,.52,.35),
    (2.53,3.06,.31,.17),(2.66,3.02,.04,.06)],skin,sides=56,subdivisions=5,parent=root)

loft('FormV4_integrated_cranial_hood',[(1.18,3.63,.35,.06),(1.60,3.62,.69,.14),(2.10,3.47,.59,.15),(2.52,3.23,.29,.10),(2.64,3.14,.045,.04)],hard,sides=40,subdivisions=5,parent=root)

# Keel and scapular ridges follow the chest, not independent spherical shoulder pads.
for side in (-1,1):
    points=spline([(side*.50,-1.2,2.8),(side*.85,-.15,3.50),(side*.85,.58,3.70),(side*.47,1.3,3.64)],7)
    tube('FormV4_shoulder_tendon',points,[.16+.10*math.sin(i/(len(points)-1)*math.pi) for i in range(len(points))],skin,14,root)
    # Recessed eye surface, eyelids embedded in the head rather than free eyebrow rings.
    helpers['eye']('FormV4_eye',(side*.52,2.05,3.40),(.13,.21,.12),eye_mat,root)
    for upper in (True,False):
        pts=[]
        for j in range(15):
            a=j/14*math.pi
            pts.append((side*(.53+.045*math.sin(a)),2.05+.205*math.cos(a),3.40+(.115 if upper else -.105)*math.sin(a)))
        tube('FormV4_embedded_lid',pts,[.048]*len(pts),skin,8,root)
    # Short tucked landing legs: hip -> forward knee -> rear hock -> spread grasping foot.
    hip=Vector((side*.76,-.40,2.40))
    knee=Vector((side*1.23,.42,1.42))
    ankle=Vector((side*.89,-.04,.57))
    foot=Vector((side*.94,.74,.20))
    pts=spline([hip,knee,ankle,foot],8)
    radii=[]
    for i in range(len(pts)):
        t=i/(len(pts)-1)
        radii.append(.32*(1-t)+.085+.075*math.exp(-((t-.36)/.12)**2))
    tube('FormV4_jointed_landing_leg',pts,radii,skin,20,root)
    for digit in range(3):
        spread=(digit-1)*.22
        pts=spline([foot,(side*.94+spread,.99,.13),(side*.94+spread*1.8,1.40+.12*(digit==1),.09),(side*.94+spread*1.9,1.59,.02)],5)
        tube('FormV4_grasping_toe',pts,[.09*(1-.7*i/(len(pts)-1)) for i in range(len(pts))],skin,10,root)
        tip=pts[-1];base=pts[-3]
        tube('FormV4_curved_claw',[base,tip,(tip[0],tip[1]+.16,tip[2]+.08)],[.045,.033,.003],hard,10,root)
    pts=spline([foot,(side*1.13,.37,.09),(side*1.25,.11,.04)],5)
    tube('FormV4_rear_grasping_digit',pts,[.08*(1-.85*i/(len(pts)-1)) for i in range(len(pts))],skin,10,root)

# Main wings have a bent leading limb and distributed fingers, no closed oval frame.
def bezier(points,t):
    a,b,c,d=[Vector(p) for p in points];u=1-t
    return a*u**3+3*b*u*u*t+3*c*u*t*t+d*t**3

def wing_point(s,t,side,fold):
    leading=bezier([(0.70,.42,3.52),(1.9,1.2,4.25),(3.65,1.7,8.5),(7.05,-.8,6.6)],s)
    trailing=bezier([(0.65,-1.1,2.7),(1.9,-3.7,2.8),(5.6,-4.1,3.3),(7.05,-.8,6.6)],s)
    # Scallops are shallow concavities between load-bearing distal ribs.
    trailing.y+=.60*abs(math.sin(s*math.pi*5))*(math.sin(math.pi*s)**.5)
    p=leading.lerp(trailing,t)
    p.z+=.36*math.sin(math.pi*t)*math.sin(math.pi*s)
    p.x=.7+(p.x-.7)*(1-.60*fold)
    p.y-=(leading.x-.7)*.43*fold
    p.z-=(leading.x-.7)*.22*fold
    p.x*=side
    return p

for side,fold in [(-1,0.0),(1,.70)]:
    wing=empty('FormV4_MainWing_'+('L' if side<0 else 'R'),parent=root)
    vertices=[];uvs=[];faces=[];ns=65;nt=25
    for i in range(ns):
        for j in range(nt):
            s=i/(ns-1);t=j/(nt-1)
            vertices.append(tuple(wing_point(s,t,side,fold)));uvs.append((s,t))
    for i in range(ns-1):
        for j in range(nt-1):
            a=i*nt+j;b=a+nt
            faces.append((a,a+1,b+1,b) if side>0 else (a,b,b+1,a+1))
    membrane_obj=mesh_object('FormV4_tension_membrane',vertices,faces,membrane,uvs,wing)
    solid=membrane_obj.modifiers.new('Thin actual membrane thickness','SOLIDIFY');solid.thickness=.018
    points=[tuple(wing_point(i/48,0,side,fold)) for i in range(49)]
    radii=[.18*(1-i/48)**.7+.015 for i in range(49)]
    tube('FormV4_shoulder_elbow_wrist_edge',points,radii,hard,14,wing)
    for s_end in [.19,.37,.56,.75,.91]:
        points=[]
        for j in range(25):
            t=j/24;s=s_end-.10*(1-t)
            p=wing_point(max(0,s),t,side,fold);p.z+=.035
            points.append(tuple(p))
        radii=[.075*(1-j/24)**.7+.009 for j in range(25)]
        tube('FormV4_tapered_branching_finger',points,radii,hard,10,wing)
    # Soft rear rim follows lobes; distinctly thinner than the leading forelimb.
    points=[tuple(wing_point(i/64,1,side,fold)) for i in range(65)]
    tube('FormV4_scalloped_tissue_margin',points,[.026]*65,skin,7,wing)

# Single tail root and caudal stabilizer, swept and curved rather than a flat rectangle.
tail_vertices=[];tail_faces=[]
for i in range(18):
    s=i/17
    for j in range(13):
        t=j/12*2-1
        width=math.sin(math.pi*s)*.72
        tail_vertices.append((t*width,-2.05-s*1.7,2.35-.22*s+.13*t*t))
for i in range(17):
    for j in range(12):
        a=i*13+j;tail_faces.append((a,a+1,a+14,a+13))
mesh_object('FormV4_single_tail_root_membrane',tail_vertices,tail_faces,membrane,parent=root)
points=spline([(0,-1.9,2.36),(0,-2.8,2.28),(0,-3.75,2.14)],6)
tube('FormV4_tail_spine',points,[.095*(1-.85*i/(len(points)-1)) for i in range(len(points))],skin,10,root)

# Neutral inspection stage; these are form views, not game/render fidelity claims.
ground_mat=clay('FormV4 stage',(.19,.21,.23))
bpy.ops.mesh.primitive_plane_add(size=100,location=(0,0,-.055))
ground=bpy.context.object;ground.name='FormV4_Ground';ground.data.materials.append(ground_mat)
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=1440;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO';scene.display.shading.studiolight_rotate_z=.45
scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH'
scene.display.shading.background_type='WORLD';scene.world.color=(.22,.25,.29)
scene.render.image_settings.file_format='PNG'
bpy.ops.object.camera_add(location=(-14,18,8))
camera=bpy.context.object;camera.name='FormV4_InspectionCamera';camera.data.type='ORTHO';camera.data.ortho_scale=17
scene.camera=camera
target=Vector((0,-.1,3.6));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/visual_fauna/aeral-mcp-forms-v4.blend'))
result={'stage':'primary form reconstruction, not accepted production mesh','file':bpy.data.filepath,'objects':len([o for o in scene.objects if o.name.startswith('FormV4')]),'wingPair':2,'tailStabilizer':1,'next':'MCP neutral front/side/back/three-quarter capture and independent critique'}
