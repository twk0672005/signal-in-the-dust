"""Original deterministic microfauna authoring, Blender 5.2 LTS, offline only."""
import bpy, math, json, hashlib, random, os, sys
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art-source/visual_microfauna'
OUT = ROOT / 'godot/assets/visual_microfauna'
EVID = ROOT / 'evidence/visual-upgrade-20260923/microfauna-authoring'
SEED = 240923
random.seed(SEED)
TAU = math.tau

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def atlas():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    u, v = (xx % 256)/256, (yy % 256)/256
    rng = np.random.default_rng(SEED)
    grain = rng.normal(0, 1, (n,n))
    growth = np.sin((u*21 + np.sin(v*9)*0.55)*TAU)
    cracks = np.maximum(0, np.sin(u*41 + np.sin(v*13)*1.4))**18
    pits = np.clip(grain-1.65, 0, 1)
    height = .38*growth + .13*grain - .7*pits - .4*cracks
    color = np.zeros((n,n,4), np.float32); color[:,:,3] = 1
    # Bottom-left chitin, bottom-right moist tissue, top-left membrane, top-right accent.
    palettes = [(.21,.235,.32),(.17,.105,.19),(.34,.49,.53),(.34,.47,.39)]
    rough = np.empty((n,n),np.float32)
    for tile,(x,y) in enumerate([(0,0),(256,0),(0,256),(256,256)]):
        h = height[y:y+256,x:x+256]
        base=np.array(palettes[tile]); variation=(h*.12 + np.sin(v[y:y+256,x:x+256]*TAU*3)*.027)[...,None]
        c=np.clip(base+variation, .025, .85)
        if tile==3:
            mask = u[y:y+256,x:x+256]>.52
            c[mask] = np.clip(np.array([.54,.31,.13])+variation[mask],.02,.85)
        if tile==2:
            veins=(np.sin(u[y:y+256,x:x+256]*TAU*19 + v[y:y+256,x:x+256]*TAU*5)>.955)
            c[veins]*=.70
            color[y:y+256,x:x+256,3]=.86
        color[y:y+256,x:x+256,:3]=c
        rough[y:y+256,x:x+256]=np.clip([.59,.30,.44,.40][tile]+h*.10,.20,.85)
    gy,gx=np.gradient(height)
    norm=np.stack([-gx*.23,-gy*.23,np.ones_like(gx)],axis=-1)
    norm/=np.linalg.norm(norm,axis=-1)[...,None]
    normal=np.ones((n,n,4),np.float32);normal[:,:,:3]=norm*.5+.5
    orm=np.ones((n,n,4),np.float32);orm[:,:,0]=1;orm[:,:,1]=rough;orm[:,:,2]=.10
    paths={}
    for name,pixels,noncolor in [('basecolor',color,False),('normal',normal,True),('orm',orm,True)]:
        path=SRC/f'microfauna_atlas_{name}.png'
        image=bpy.data.images.new(f'MicrofaunaAtlas_{name}',width=n,height=n,alpha=True)
        if noncolor:image.colorspace_settings.name='Non-Color'
        image.pixels.foreach_set(pixels.ravel()); image.filepath_raw=str(path);image.file_format='PNG';image.save()
        paths[name]=path
    return paths

def material(name, paths, membrane=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    m.diffuse_color=(.3,.4,.5,.86 if membrane else 1)
    tree=m.node_tree; p=tree.nodes.get('Principled BSDF')
    textures={}
    for k,path in paths.items():
        node=tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(path),check_existing=True)
        if k!='basecolor':node.image.colorspace_settings.name='Non-Color'
        textures[k]=node
    tree.links.new(textures['basecolor'].outputs['Color'],p.inputs['Base Color'])
    split=tree.nodes.new('ShaderNodeSeparateColor');tree.links.new(textures['orm'].outputs['Color'],split.inputs[0])
    tree.links.new(split.outputs['Green'],p.inputs['Roughness']);tree.links.new(split.outputs['Blue'],p.inputs['Metallic'])
    normal=tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.38
    tree.links.new(textures['normal'].outputs['Color'],normal.inputs['Color']);tree.links.new(normal.outputs[0],p.inputs['Normal'])
    p.inputs['Specular IOR Level'].default_value=.35
    if membrane:
        tree.links.new(textures['basecolor'].outputs['Alpha'],p.inputs['Alpha'])
        m.surface_render_method='DITHERED';m.use_backface_culling=False
    return m

TILES={'shell':(0,0), 'soft':(1,0), 'membrane':(0,1), 'accent':(1,1)}
def uv_at(u,v,tile):
    tx,ty=TILES[tile];return ((tx+.055+.89*u)*.5,(ty+.055+.89*v)*.5)

class Geo:
    def __init__(self):self.v=[];self.f=[];self.uv=[];self.w=[];self.mat=[]
    def vert(self,p,uv,weight):
        self.v.append(tuple(p));self.uv.append(uv);self.w.append(weight if isinstance(weight,dict) else {weight:1});return len(self.v)-1
    def face(self,ids,mat=0):self.f.append(ids);self.mat.append(mat)
    def tube(self,points,radii,bone,tile='shell',sides=7,mat=0):
        points=list(map(Vector,points));ids=[]
        for i,p in enumerate(points):
            tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            ref=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
            a=tangent.cross(ref).normalized();b=tangent.cross(a).normalized()
            row=[]
            for j in range(sides+1):
                ang=j/sides*TAU;r=radii[i]
                row.append(self.vert(p+r*(a*math.cos(ang)+b*math.sin(ang)),uv_at(j/sides,i/(len(points)-1),tile),bone))
            ids.append(row)
        for i in range(len(ids)-1):
            for j in range(sides):self.face((ids[i][j],ids[i+1][j],ids[i+1][j+1],ids[i][j+1]),mat)
        self.face(tuple(reversed(ids[0][:-1])),mat);self.face(tuple(ids[-1][:-1]),mat)
    def ellipsoid(self,center,scale,bone,tile='soft',nu=14,nv=8,mat=0):
        ids=[]
        for i in range(nv+1):
            ph=.005+(math.pi-.010)*i/nv
            row=[]
            for j in range(nu+1):
                th=j/nu*TAU
                p=(center[0]+scale[0]*math.sin(ph)*math.cos(th),center[1]+scale[1]*math.sin(ph)*math.sin(th),center[2]+scale[2]*math.cos(ph))
                row.append(self.vert(p,uv_at(j/nu,i/nv,tile),bone))
            ids.append(row)
        for i in range(nv):
            for j in range(nu):self.face((ids[i][j],ids[i+1][j],ids[i+1][j+1],ids[i][j+1]),mat)
        self.face(tuple(reversed(ids[0][:-1])),mat);self.face(tuple(ids[-1][:-1]),mat)
    def loft(self,sections,bone,tile='soft',sides=24):
        ids=[]
        for i,(y,z,rx,rz) in enumerate(sections):
            row=[]
            for j in range(sides+1):
                a=j/sides*TAU; ripple=1+.022*math.cos(6*a+i*.6)
                row.append(self.vert((rx*math.cos(a)*ripple,y,z+rz*math.sin(a)*ripple),uv_at(j/sides,i/(len(sections)-1),tile),bone))
            ids.append(row)
        for i in range(len(ids)-1):
            for j in range(sides):self.face((ids[i][j],ids[i][j+1],ids[i+1][j+1],ids[i+1][j]))
        self.face(tuple(ids[0][:-1]));self.face(tuple(reversed(ids[-1][:-1])))
    def plate(self,y,rx,ry,z,rise,bone,index):
        ids=[];nx=16;ny=8
        for i in range(ny+1):
            t=i/ny; row=[]
            for j in range(nx+1):
                s=j/nx*2-1
                width=rx*(.25+.75*math.sin(math.pi*(.12+.80*t))**.65)
                x=s*width
                py=y+(t-.5)*ry + .012*(1-s*s)*(1-t)
                pz=z+rise*(1-s*s)**.62 + .006*math.sin(t*math.pi) + .0025*math.cos(s*math.pi*4+index)*math.sin(t*math.pi)
                row.append(self.vert((x,py,pz),uv_at(j/nx,i/ny,'shell'),bone))
            ids.append(row)
        for i in range(ny):
            for j in range(nx):self.face((ids[i][j],ids[i+1][j],ids[i+1][j+1],ids[i][j+1]))
        # Thin thickened lower surface creates a physical shell edge, not an open card.
        low={}
        for row in ids:
            for v in row:
                p=Vector(self.v[v]);p.z-=.0032;low[v]=self.vert(p,self.uv[v],bone)
        for i in range(ny):
            for j in range(nx):self.face((low[ids[i][j+1]],low[ids[i+1][j+1]],low[ids[i+1][j]],low[ids[i][j]]))
        perimeter=ids[0]+[ids[i][-1] for i in range(1,ny+1)]+list(reversed(ids[-1][:-1]))+[ids[i][0] for i in range(ny-1,0,-1)]
        for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):self.face((a,b,low[b],low[a]))
    def object(self,name,materials,rig):
        mesh=bpy.data.meshes.new(name+'_geometry');mesh.from_pydata(self.v,[],self.f);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        for m in materials:mesh.materials.append(m)
        uv=mesh.uv_layers.new(name='AtlasUV')
        for poly in mesh.polygons:
            poly.material_index=self.mat[poly.index];poly.use_smooth=True
            for li in poly.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        groups={}
        for i,weights in enumerate(self.w):
            for b,w in weights.items():
                if b not in groups:groups[b]=obj.vertex_groups.new(name=b)
                groups[b].add([i],w,'REPLACE')
        mod=obj.modifiers.new('MicrofaunaSkeleton','ARMATURE');mod.object=rig
        obj.parent=rig
        return obj

def make_rig(name,bones):
    arm=bpy.data.armatures.new(name+'_skeleton');rig=bpy.data.objects.new(name+'_rig',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,a,b,parent in bones:
        bone=arm.edit_bones.new(name);bone.head=a;bone.tail=b
        if parent:bone.parent=arm.edit_bones[parent]
        bone.align_roll(Vector((0,0,1)))
    bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
    for p in rig.pose.bones:p.rotation_mode='QUATERNION'
    return rig

def bone_matrix(a,b):
    mat=(Vector(b)-Vector(a)).to_track_quat('Y','Z').to_matrix().to_4x4();mat.translation=Vector(a);return mat

def set_global(rig,desired,frame):
    for name,mat in desired.items():
        p=rig.pose.bones[name]
        if p.parent:
            parentmat=desired.get(p.parent.name,p.parent.bone.matrix_local)
            p.matrix_basis=p.bone.matrix_local.inverted() @ p.parent.bone.matrix_local @ parentmat.inverted() @ mat
        else:p.matrix_basis=p.bone.matrix_local.inverted() @ mat
        for prop in ('location','rotation_quaternion','scale'):p.keyframe_insert(prop,frame=frame,group=name)

def new_action(rig,name):
    rig.animation_data_create();rig.animation_data.action=None
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    a=bpy.data.actions.new(name);rig.animation_data.action=a;return a

def stash(rig,action,end):
    action.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=action.name
    strip=track.strips.new(action.name,1,action);strip.action_frame_start=1;strip.action_frame_end=end;track.mute=True
    rig.animation_data.action=None

def crawler():
    bones=[('root',(0,0,.065),(0,.06,.065),None)]
    legs=[]
    for s in [-1,1]:
        for i,y in enumerate([-.085,.008,.097]):
            h=Vector((s*.062,y,.077));k=Vector((s*(.124 if i!=1 else .133),y+(.016 if i==2 else -.012),.061));f=Vector((s*(.158 if i!=1 else .169),y+(.043 if i==2 else -.035),.009))
            prefix=f'leg_{"L" if s<0 else "R"}_{i+1}'
            bones.extend([(prefix+'_upper',h,k,'root'),(prefix+'_lower',k,f,prefix+'_upper')]);legs.append((s,i,prefix,h,k,f))
    for s in [-1,1]:bones.append((f'feeler_{s}',(s*.025,.156,.073),(s*.040,.202,.077),'root'))
    rig=make_rig('detritus_crawler_01',bones);g=Geo()
    g.loft([(-.177,.069,.004,.008),(-.161,.073,.039,.023),(-.12,.075,.065,.034),(-.065,.078,.078,.039),(-.01,.078,.080,.042),(.05,.077,.070,.040),(.108,.076,.058,.037),(.146,.075,.043,.028),(.175,.073,.007,.013)],'root')
    for i,y in enumerate([-.135,-.091,-.047,-.003,.041,.086]):
        rx=[.056,.073,.082,.084,.077,.065][i]
        g.plate(y,rx,.069,.084,[.031,.037,.045,.045,.043,.035][i],'root',i)
    g.plate(.133,.046,.057,.079,.026,'root',7)
    # Fitted side folds and elongated cyan/amber chemoreceptor seams, not luminous balls.
    for s in [-1,1]:
        for i,y in enumerate([-.118,-.076,-.034,.008,.05,.092]):
            x=s*[.049,.065,.073,.072,.064,.050][i]
            g.tube([(x,y-.009,.069),(x+s*.006,y,.073),(x,y+.01,.071)],[.003,.0045,.002], 'root','soft',6)
            if i in (1,4):g.tube([(x,y-.01,.083),(x+s*.003,y,.087),(x,y+.009,.085)],[.0015,.002,.001],'root','accent',6)
        fb=f'feeler_{s}'
        g.tube([(s*.025,.15,.074),(s*.035,.175,.080),(s*.052,.198,.071),(s*.059,.211,.065)],[.004,.0031,.0019,.0006],fb,'soft',7)
        g.ellipsoid((s*.031,.15,.089),(.009,.014,.006),'root','shell',12,6)
        # Two short ventral scraping palps.
        g.tube([(s*.018,.163,.063),(s*.016,.180,.052),(s*.009,.183,.050)],[.006,.004,.0018],'root','soft',7)
    for s,i,p,h,k,f in legs:
        g.ellipsoid(h,(.012,.015,.011),p+'_upper','soft',12,6)
        g.tube([h,h.lerp(k,.32)+Vector((0,0,.004)),k],[.009,.010,.0058],p+'_upper','shell',9)
        g.ellipsoid(k,(.008,.010,.008),p+'_lower','soft',12,6)
        g.tube([k,k.lerp(f,.5)+Vector((s*.006,0,.003)),f],[.0068,.0058,.003],p+'_lower','shell',8)
        toe=f+Vector((s*.009,.008,-.006))
        g.tube([f,f.lerp(toe,.6),toe],[.003,.0035,.0013],p+'_lower','soft',7)
        g.ellipsoid(toe+Vector((0,0,-.001)),(.005,.009,.002),p+'_lower','soft',10,5)
    obj=g.object('detritus_crawler_01',MATS[:1],rig)
    idle=new_action(rig,'idle')
    for frame in range(1,50,4):
        for s in [-1,1]:
            pb=rig.pose.bones[f'feeler_{s}'];pb.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((.035*s*math.sin((frame-1)/48*TAU),.012*math.sin((frame-1)/48*TAU),1)).normalized());pb.keyframe_insert('rotation_quaternion',frame=frame)
    stash(rig,idle,49)
    walk=new_action(rig,'walk')
    for frame in range(1,26):
        desired={'root':rig.data.bones['root'].matrix_local.copy()}
        for s,i,p,h,k,f in legs:
            phase=((frame-1)/24 + (.5 if (i+(s>0))%2 else 0))%1
            target=f.copy();target.y += .018*math.cos(phase*TAU);target.z += .018*max(0,math.sin(phase*TAU))
            upper=(k-h).length;lower=(f-k).length;delta=target-h;distance=delta.length;direction=delta.normalized()
            along=(upper*upper-lower*lower+distance*distance)/(2*distance)
            height=math.sqrt(max(0,upper*upper-along*along))
            elbow=Vector((s,0,.65));elbow=(elbow-direction*elbow.dot(direction)).normalized()
            knee=h+direction*along+elbow*height
            desired[p+'_upper']=bone_matrix(h,knee);desired[p+'_lower']=bone_matrix(knee,target)
        set_global(rig,desired,frame)
    stash(rig,walk,25)
    return rig,obj,{'body_length_m':.352,'clips':{'idle':[1,49],'walk':[1,25]},'six_feet':True}

def flier():
    bones=[('root',(0,0,0),(0,.065,0),None),('abdomen',(0,-.020,0),(0,-.13,-.009),'root')]
    for s in [-1,1]:
        for typ in ['fore','hind']:
            y=.018 if typ=='fore' else -.02
            bones.extend([(f'{typ}_{s}',(s*.022,y,.009),(s*.17,y,.025),'root'),(f'{typ}_tip_{s}',(s*.17,y,.025),(s*.32,y,.04),f'{typ}_{s}')])
    rig=make_rig('membrane_flier_01',bones);g=Geo()
    g.loft([(-.133,-.010,.003,.004),(-.114,-.004,.012,.011),(-.087,-.001,.018,.016),(-.057,0,.020,.019),(-.027,.002,.020,.019),(.0,.004,.028,.025),(.034,.008,.030,.027),(.058,.008,.023,.021),(.081,.006,.021,.017),(.088,.005,.007,.009)],'root','soft',20)
    for i,y in enumerate([-.112,-.085,-.058,-.031]):
        g.plate(y,[.010,.016,.019,.020][i],.031,.007,.012,'abdomen',i)
    g.plate(.021,.029,.068,.018,.018,'root',5)
    for s in [-1,1]:
        g.ellipsoid((s*.017,.071,.018),(.009,.013,.007),'root','shell',12,7)
        g.tube([(s*.010,.080,.008),(s*.016,.101,.014),(s*.024,.113,.011)],[.0026,.0017,.0005],'root','soft',6)
        # Three compact articulated hooks each side: visible gripping anatomy without long bird legs.
        for i,y in enumerate([.038,.012,-.011]):
            g.tube([(s*.020,y,-.005),(s*.032,y+.009,-.017),(s*.027,y+.026,-.038),(s*.013,y+.030,-.042),(s*.015,y+.023,-.047)],[.004,.004,.0028,.0018,.0006],'root','soft',7)
        g.tube([(s*.016,.041,.027),(s*.021,.032,.030),(s*.020,.024,.030)],[.0015,.002,.001],'root','accent',6)
        for typ in ['fore','hind']:
            fore=typ=='fore';rooty=.023 if fore else -.016;length=.301 if fore else .239
            nx,ny=20,10;grid=[]
            def wing(t,q):
                x=s*(.023+length*t)
                center=rooty+(.057*t if fore else -.112*t)+.024*math.sin(math.pi*t)
                chord=(.072 if fore else .081)*math.sin(math.pi*t)**.66 +.003
                y=center+(q-.44)*2*chord
                z=.015+.038*math.sin(math.pi*t*.77)+.011*(1-(2*q-1)**2)*math.sin(math.pi*t)
                return Vector((x,y,z))
            def weights(t):
                b=f'{typ}_{s}';tip=f'{typ}_tip_{s}';w=max(0,min(1,(t-.34)/.44));return {b:1-w,tip:w}
            for i in range(nx+1):
                t=i/nx;row=[]
                for j in range(ny+1):row.append(g.vert(wing(t,j/ny),uv_at(t,j/ny,'membrane'),weights(t)))
                grid.append(row)
            for i in range(nx):
                for j in range(ny):
                    face=(grid[i][j],grid[i+1][j],grid[i+1][j+1],grid[i][j+1]);g.face(face if s>0 else tuple(reversed(face)),1)
            # Curved wing edge and six branching ribs carry the membrane.
            for q,radius in [(0,.0021),(1,.0015)]:
                points=[wing(k/16,q) for k in range(17)]
                # Per-ring weighting is patched after tube creation to deform veins with tissue.
                before=len(g.v);g.tube(points,[radius*(1-.65*k/16) for k in range(17)],f'{typ}_{s}','shell',6)
                for offset in range(len(g.v)-before):g.w[before+offset]=weights((offset//7)/16)
            for rib in range(1,7):
                end=.24+rib*.10;points=[];ts=[]
                for k in range(7):
                    t=.10+(end-.10)*k/6;q=.03+.95*(k/6)**.85;points.append(wing(t,q)+Vector((0,0,.0007)));ts.append(t)
                before=len(g.v);g.tube(points,[.0014*(1-.65*k/6) for k in range(7)],f'{typ}_{s}','shell',5)
                for offset in range(len(g.v)-before):g.w[before+offset]=weights(ts[min(6,offset//6)])
    obj=g.object('membrane_flier_01',MATS,rig)
    flutter=new_action(rig,'flutter')
    for frame in range(1,26):
        phase=(frame-1)/24*TAU*4
        for s in [-1,1]:
            for typ in ['fore','hind']:
                offset=0 if typ=='fore' else .65
                for distal in [False,True]:
                    name=f'{typ}_tip_{s}' if distal else f'{typ}_{s}'
                    angle=math.radians((12*math.sin(phase+offset-.7)) if distal else (31*math.sin(phase+offset)+7))*s
                    pb=rig.pose.bones[name];pb.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((math.sin(angle),0,math.cos(angle))));pb.keyframe_insert('rotation_quaternion',frame=frame)
        pb=rig.pose.bones['abdomen'];pb.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((0,.04*math.sin(phase-.5),1)).normalized());pb.keyframe_insert('rotation_quaternion',frame=frame)
    stash(rig,flutter,25)
    return rig,obj,{'body_length_m':.221,'wingspan_rest_m':.648,'clips':{'flutter':[1,25]},'wing_pairs':2}

def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)

def export_one(name,maker):
    clean();scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1;scene.render.fps=24
    rig,obj,meta=maker()
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    scene.frame_set(1);scene.frame_end=49 if name.startswith('detritus') else 25
    rig.animation_data.action=None
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    for track in rig.animation_data.nla_tracks:track.mute=False
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);obj.select_set(True)
    blend=SRC/f'{name}.blend';glb=OUT/f'{name}.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    kwargs=dict(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_nla_strips=True,export_yup=True,export_apply=False,export_skins=True,export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True,export_cameras=False,export_lights=False,export_extras=True)
    supported=set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys());kwargs={k:v for k,v in kwargs.items() if k in supported}
    bpy.ops.export_scene.gltf(**kwargs)
    mesh=obj.data;mesh.calc_loop_triangles()
    meta.update({'blend':str(blend),'glb':str(glb),'source_triangles':len(mesh.loop_triangles),'mesh_objects':1,'material_slots':len(mesh.materials),'bones':len(rig.data.bones),'vertices':len(mesh.vertices),'uv_layer':'AtlasUV','blender_version':bpy.app.version_string})
    return meta

if __name__=='__main__':
    bpy.ops.wm.read_factory_settings(use_empty=True)
    paths=atlas();MATS=[material('microfauna_mineral_soft_atlas',paths),material('microfauna_thin_membrane_atlas',paths,True)]
    reports={name:export_one(name,fn) for name,fn in [('detritus_crawler_01',crawler),('membrane_flier_01',flier)]}
    reports['atlas']={k:{'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)} for k,p in paths.items()}
    reports['generator_sha256']=sha(__file__);reports['blender_version']=bpy.app.version_string;reports['process_id']=os.getpid()
    (EVID/'authoring-report.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
    print('MICROFAUNA_AUTHORING_COMPLETE '+json.dumps(reports))
