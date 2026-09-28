"""Original deterministic flora modelling; Blender 5.2 LTS, standard glTF PBR.
All lengths in metres. No downloads, addon dependencies or runtime changes.
Run: blender --background --factory-startup --python build_flora.py -- --families canopy,sails
"""
import bpy, math, random, json, hashlib, argparse, sys
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art-source/visual_flora'
OUT = ROOT / 'godot/assets/visual_flora'
EVIDENCE = ROOT / 'evidence/visual-upgrade-20260923/flora-authoring'
for d in (SOURCE, OUT / 'textures', EVIDENCE): d.mkdir(parents=True, exist_ok=True)
TAU = math.tau
SEED = 230923
R = random.Random(SEED)
MATERIALS = {}
GROUPS = {}

def noise(x, y, seed):
    rng=np.random.default_rng(SEED+seed)
    result=np.zeros_like(x)
    for cells,weight in ((5,.43),(13,.28),(31,.17),(79,.08),(181,.04)):
        values=rng.uniform(-1,1,(cells+1,cells+1))
        xx=x*cells;yy=y*cells;ix=xx.astype(int);iy=yy.astype(int)
        fx=xx-ix;fy=yy-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
        result+=weight*((1-fx)*(1-fy)*values[iy,ix]+fx*(1-fy)*values[iy,ix+1]+(1-fx)*fy*values[iy+1,ix]+fx*fy*values[iy+1,ix+1])
    return result*1.7

def vascular_network(x,y,seed):
    # Irregular closed vascular cells, avoiding a repeated sinusoidal stripe field.
    rng=np.random.default_rng(SEED+seed)
    first=np.full_like(x,1e6);second=np.full_like(x,1e6)
    gx=x*9;gy=y*13
    for j in range(13):
        for i in range(9):
            sx=i+rng.uniform(.12,.88);sy=j+rng.uniform(.12,.88)
            dx=(gx-sx+4.5)%9-4.5;dy=(gy-sy+6.5)%13-6.5
            dist=dx*dx+dy*dy
            new_first=np.minimum(first,dist)
            second=np.minimum(second,np.maximum(first,dist));first=new_first
    return np.exp(-(np.sqrt(second)-np.sqrt(first))*32)

def image_map(name, data, noncolor=False):
    path = OUT / 'textures' / (name + '.png')
    h, w = data.shape[:2]
    im = bpy.data.images.new(name, width=w, height=h, alpha=True)
    if noncolor: im.colorspace_settings.name = 'Non-Color'
    pixels = np.ones((h, w, 4), dtype=np.float32)
    if data.ndim == 2: pixels[:,:,:3] = data[:,:,None]
    else: pixels[:,:,:3] = data[:,:,:3]
    im.pixels.foreach_set(pixels.ravel())
    im.file_format='PNG'; im.filepath_raw=str(path); im.save(); im.pack()
    return im

def material(name, base, kind, rough=.55, emission=None, alpha=1):
    mat = bpy.data.materials.new(name); mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*base,1)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Specular IOR Level'].default_value=.32
    mat.diffuse_color=(*base,alpha)
    if emission:
        bs.inputs['Emission Color'].default_value=(*emission,1)
        bs.inputs['Emission Strength'].default_value=2.3
    if kind != 'light':
        n=512
        y,x=np.mgrid[0:n,0:n].astype(float)/n
        f=noise(x,y,1)
        if kind in ('bark','decay'):
            ridge=np.sin((x + .027*np.sin(y*26)+.012*f)*TAU*16)
            cracks=np.power(np.maximum(0,ridge),13)
            grain=.5+.35*f
            height=grain*.34-cracks*.33
            col=np.clip(.92+.42*f-.30*cracks,.25,1.4)
        elif kind in ('canopy','sail'):
            veins=vascular_network(x,y,7 if kind=='canopy' else 19)
            fibers=np.exp(-np.abs(np.sin((x+.004*f)*TAU*57))*16)
            height=.065*f+.10*veins+.012*fibers
            col=.87+.19*f+.16*veins+.015*fibers
        elif kind=='cup':
            veins=vascular_network(x,y,31)
            height=.06*f+.06*veins
            col=.87+.18*f+.13*veins-.06*y
        elif kind=='pod':
            wrinkles=np.sin(y*160 + f*4)
            height=.13*f+.013*wrinkles+.018*np.cos(x*TAU*8)
            col=.89+.30*f+.015*wrinkles
        elif kind in ('gill','edge'):
            pores=np.power(np.maximum(0,np.sin(x*103+f)*np.cos(y*123-f)),7)
            height=.1*f-.4*pores
            col=.82+.18*f-.58*pores
        else:
            height=.22*f
            col=.8+.22*f
        rgb=np.stack([np.clip(base[i]*col*(1+f*(.04 if i==0 else -.025)),0,1) for i in range(3)],axis=-1)
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image_map(name+'_albedo',rgb)
        mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
        dx=np.roll(height,-1,axis=1)-np.roll(height,1,axis=1)
        dy=np.roll(height,-1,axis=0)-np.roll(height,1,axis=0)
        normal=np.stack([-dx*3.2,-dy*3.2,np.ones_like(dx)],axis=-1)
        normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        texn=mat.node_tree.nodes.new('ShaderNodeTexImage'); texn.image=image_map(name+'_normal',normal*.5+.5,True)
        nm=mat.node_tree.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=.72
        mat.node_tree.links.new(texn.outputs['Color'],nm.inputs['Color']); mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
        texr=mat.node_tree.nodes.new('ShaderNodeTexImage'); texr.image=image_map(name+'_roughness',np.clip(rough+.10*f,0,1),True)
        mat.node_tree.links.new(texr.outputs['Color'],bs.inputs['Roughness'])
        if name=='wax_pod':
            mask=(np.maximum(0,np.sin(x*TAU*7))**9)*np.exp(-((y-.48)/.20)**4)
            mask*=np.clip(.65+f,0,1)
            glow=np.stack([mask*.82,mask*.30,mask*.026],axis=-1)
            texe=mat.node_tree.nodes.new('ShaderNodeTexImage');texe.image=image_map(name+'_emission',glow)
            mat.node_tree.links.new(texe.outputs['Color'],bs.inputs['Emission Color'])
            bs.inputs['Emission Strength'].default_value=1.15
    if alpha<1:
        bs.inputs['Alpha'].default_value=alpha
        mat.surface_render_method='DITHERED'
        mat.use_backface_culling=False
    MATERIALS[name]=mat
    return mat

def init_materials():
    material('mineral_bark',(.38,.32,.25),'bark',.76)
    material('bark_ridge',(.47,.40,.31),'bark',.71)
    material('damp_root',(.21,.25,.21),'bark',.57)
    material('canopy_tissue',(.33,.53,.54),'canopy',.43)
    material('sail_tissue',(.47,.56,.67),'sail',.39,alpha=.94)
    material('sail_rib',(.47,.39,.30),'bark',.58)
    material('wax_pod',(.48,.29,.11),'pod',.44)
    material('unripe_pod',(.23,.27,.22),'pod',.52)
    material('inner_pod',(.73,.40,.13),'pod',.4)
    material('shore_inner',(.17,.36,.38),'cup',.25)
    material('shore_outer',(.30,.24,.36),'cup',.48)
    material('shore_lip',(.44,.33,.36),'pod',.36)
    material('nutrient_film',(.25,.33,.29),'film',.34)
    material('mineral_grain',(.33,.31,.25),'bark',.74)
    material('decaying_root',(.19,.145,.19),'decay',.82)
    material('spore_crust',(.27,.18,.26),'edge',.74)
    material('soft_gills',(.69,.59,.72),'gill',.44)
    material('cyan_organ',(.08,.35,.39),'light',.32,emission=(.035,.56,.68))
    material('amber_organ',(.64,.30,.03),'light',.35,emission=(.92,.32,.025))

class Mesh:
    def __init__(self,name,mat,pivot=(0,0,0)):
        self.name=name; self.mat=mat; self.pivot=Vector(pivot); self.v=[]; self.f=[]; self.uv=[]
    def add(self,vs,fs,uvs=None):
        n=len(self.v)
        self.v.extend(vs); self.f.extend(tuple(i+n for i in f) for f in fs)
        self.uv.extend(uvs if uvs else [(v[0],v[1]) for v in vs])
    def object(self,parent):
        if not self.v:return None
        mesh=bpy.data.meshes.new(self.name)
        # Triangulate deterministically and discard collapsed pole/heel triangles.
        triangles=[];discarded=0
        for face in self.f:
            for i in range(1,len(face)-1):
                a,b,c=face[0],face[i],face[i+1]
                if (Vector(self.v[b])-Vector(self.v[a])).cross(Vector(self.v[c])-Vector(self.v[a])).length_squared<1e-16:
                    discarded+=1;continue
                triangles.append((a,b,c))
        mesh.from_pydata([tuple(Vector(v)-self.pivot) for v in self.v],[],triangles); mesh.update()
        obj=bpy.data.objects.new(self.name,mesh); bpy.context.collection.objects.link(obj)
        obj.location=self.pivot; obj.parent=parent
        obj['discarded_degenerate_triangles']=discarded
        uv=mesh.uv_layers.new(name='UVMap')
        for poly in mesh.polygons:
            poly.use_smooth=True
            for loop in poly.loop_indices: uv.data[loop].uv=self.uv[mesh.loops[loop].vertex_index]
        obj.data.materials.append(MATERIALS[self.mat])
        return obj

def group(name,mat,pivot=(0,0,0)):
    if name not in GROUPS:GROUPS[name]=Mesh(name,mat,pivot)
    return GROUPS[name]

def spline(points,steps=32):
    p=[Vector(points[0])]+[Vector(v) for v in points]+[Vector(points[-1])]
    out=[]
    for j in range(steps+1):
        t=j/steps*(len(points)-1); i=min(int(t),len(points)-2); u=t-i
        a,b,c,d=p[i:i+4]
        out.append(.5*((2*b)+(-a+c)*u+(2*a-5*b+4*c-d)*u*u+(-a+3*b-3*c+d)*u*u*u))
    return out

def tube(target,points,radius=.1,sides=10,steps=20,ridges=.12,flatten=1):
    ps=spline(points,steps); vs=[]; fs=[]; uv=[]; dist=0
    for j,p in enumerate(ps):
        t=j/steps
        tangent=(ps[min(steps,j+1)]-ps[max(0,j-1)]).normalized()
        guide=Vector((0,0,1)) if abs(tangent.z)<.92 else Vector((0,1,0))
        xx=tangent.cross(guide).normalized(); yy=tangent.cross(xx).normalized()
        rr=radius(t) if callable(radius) else radius
        if j:dist+=(ps[j]-ps[j-1]).length
        for i in range(sides+1):
            ang=TAU*i/sides
            r=rr*(1+ridges*math.sin(ang*5+t*9)+ridges*.4*math.sin(ang*9-t*14))
            vs.append(tuple(p+xx*math.cos(ang)*r+yy*math.sin(ang)*r*flatten));uv.append((i/sides,dist*.5))
    for j in range(steps):
        for i in range(sides):
            a=j*(sides+1)+i;fs.append((a,a+1,a+sides+2,a+sides+1))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple(steps*(sides+1)+i for i in range(sides)))
    target.add(vs,fs,uv)
    return ps

def ellipsoid(target,center,scale,segments=12,rings=8,phase=0):
    vs=[];uv=[];fs=[]
    for j in range(rings+1):
        t=math.pi*j/rings
        for i in range(segments+1):
            a=TAU*i/segments
            wobble=1+.035*math.sin(a*5+t*9+phase)
            vs.append((center[0]+scale[0]*math.sin(t)*math.cos(a)*wobble,center[1]+scale[1]*math.sin(t)*math.sin(a)*wobble,center[2]+scale[2]*math.cos(t)))
            uv.append((i/segments,j/rings))
    for j in range(rings):
        for i in range(segments):
            a=j*(segments+1)+i;fs.append((a,a+1,a+segments+2,a+segments+1))
    target.add(vs,fs,uv)

def grid_shell(target,fn,nu,nv,thickness=.04,reverse=False,mask=None,back_target=None):
    front=[Vector(fn(i/nu,j/nv)) for j in range(nv+1) for i in range(nu+1)]
    normals=[]
    for j in range(nv+1):
        for i in range(nu+1):
            dx=front[j*(nu+1)+min(nu,i+1)]-front[j*(nu+1)+max(0,i-1)]
            dy=front[min(nv,j+1)*(nu+1)+i]-front[max(0,j-1)*(nu+1)+i]
            n=dx.cross(dy).normalized()
            if n.length<.1:n=Vector((0,0,1))
            normals.append(n)
    vs=[tuple(p+n*thickness*.5) for p,n in zip(front,normals)]+[tuple(p-n*thickness*.5) for p,n in zip(front,normals)]
    uv=[(i/nu,j/nv) for j in range(nv+1) for i in range(nu+1)]*2
    N=len(front);fs=[];backs=[];active=set()
    for j in range(nv):
        for i in range(nu):
            if mask and not mask(i,j):continue
            a=j*(nu+1)+i;q=(a,a+1,a+nu+2,a+nu+1)
            fs.append(q);backs.append(tuple(k+N for k in reversed(q)));active.add((i,j))
    for i,j in active:
        a=j*(nu+1)+i
        for ni,nj,b,c in [(i,j-1,a+1,a),(i+1,j,a+nu+2,a+1),(i,j+1,a+nu+1,a+nu+2),(i-1,j,a,a+nu+1)]:
            if (ni,nj) not in active:fs.append((b,c,c+N,b+N))
    target.add(vs,fs+(backs if back_target is None else []),uv)
    if back_target:back_target.add(vs,backs,uv)

def bark_plates(target,path,radius,count=30,width=.32):
    # Overlapping tapering mineral scales follow the branch, with lifted pointed ends.
    for k in range(count):
        t=(k+.5)/count; q=t*(len(path)-1);idx=min(int(q),len(path)-2)
        p=path[idx].lerp(path[idx+1],q-idx)
        tangent=(path[min(len(path)-1,idx+1)]-path[max(0,idx-1)]).normalized()
        guide=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((0,0,1))
        xx=tangent.cross(guide).normalized(); yy=tangent.cross(xx).normalized()
        rr=radius(t) if callable(radius) else radius
        for side in range(5):
            a=side*TAU/5+.34*math.sin(k*.93)+R.uniform(-.13,.13)
            normal=xx*math.cos(a)+yy*math.sin(a);across=tangent.cross(normal).normalized()
            leng=width*(1.3+R.random())*(1-.3*t);w=width*(.65+R.random()*.4)
            base=p+normal*rr*.94
            vs=[tuple(base-tangent*leng*.4-across*w),tuple(base-tangent*leng*.56),tuple(base-tangent*leng*.4+across*w),tuple(base+tangent*leng*.4+across*w*.6+normal*width*.10),tuple(base+tangent*leng*.72+normal*width*.24),tuple(base+tangent*leng*.4-across*w*.6+normal*width*.10),tuple(base+normal*width*.14)]
            fs=[(i,(i+1)%6,6) for i in range(6)]
            target.add(vs,fs,[(0,0),(.5,0),(1,0),(1,1),(.5,1.4),(0,1),(.5,.6)])

def roots(base,spread,height,tag='root',count=8):
    body=group(tag+'_body','damp_root');plate=group(tag+'_ridges','mineral_bark')
    for i in range(count):
        a=TAU*i/count+R.uniform(-.2,.2);length=spread*R.uniform(.72,1.13)
        p=[(base[0]+math.cos(a)*length,base[1]+math.sin(a)*length,-.12),
           (base[0]+math.cos(a)*length*.68,base[1]+math.sin(a)*length*.67,.12),
           (base[0]+math.cos(a)*length*.25,base[1]+math.sin(a)*length*.27,height*.38),
           (base[0],base[1],height)]
        rad=lambda t: .025+(spread*.095)*math.sin(t*math.pi*.68)**.8
        ps=tube(body,p,rad,12,24,.22,.72)
        bark_plates(plate,ps,rad,12,spread*.09)
        # Smaller root splits lie against terrain, not floating ornamental tendrils.
        start=Vector(p[1]);tip=Vector(p[0])+Vector((math.cos(a+.65)*length*.35,math.sin(a+.65)*length*.35,0))
        tube(body,[start, start.lerp(tip,.55)+Vector((0,0,.08)),tip],lambda t:spread*.04*(1-t)+.018,8,14,.2)

def canopy():
    wood=group('Canopy_primary_load_arches','mineral_bark');plates=group('Canopy_overlapping_mineral_scales','bark_ridge')
    tissue=group('Canopy_vaulted_living_roof','canopy_tissue');ribs=group('Canopy_raised_roof_ribs','sail_rib')
    organs=group('Canopy_sparse_cyan_organs','cyan_organ');tendrils=group('Canopy_pendant_epiphyte','damp_root')
    arches=[([(-10,-2,0),(-9.8,-1.2,4.5),(-8.7,.1,9.7),(-4.9,.6,15.3),(1.2,1.3,18.1),(7.5,2.1,14.1),(11,2.8,5.2),(12,3.4,0)],1.2),
            ([(-8.8,3,0),(-8,3.5,7),(-4.2,4.7,13.5),(2,5.7,16.4),(9.8,5.8,11.1),(12,5.6,0)],.88)]
    paths=[]
    for k,(pts,scale) in enumerate(arches):
        rad=lambda t,s=scale:s*(.44+.53*abs(2*t-1)**1.3)*(1+.14*math.sin(t*19))
        ps=tube(wood,pts,rad,20,86,.19); paths.append(ps)
        bark_plates(plates,ps,rad,57,.54*scale)
        roots(pts[0],4.4*scale,3.2,tag='Canopy_left_roots_'+str(k),count=8)
        roots(pts[-1],3.8*scale,3.1,tag='Canopy_right_roots_'+str(k),count=7)
    # Distinct broad saddle vaults: secondary arches fan from load-bearing arch.
    for band in range(3):
        t0=.19+band*.20;t1=t0+.38
        p0=paths[0][int(t0*86)];p1=paths[0][min(82,int(t1*86))]
        width=5.5-band*.65
        def roof(u,v):
            pp=p0.lerp(p1,u)
            pp.z+=math.sin(math.pi*u)*(2.7-band*.2)
            pp.y+=v*width
            pp.x+=(v**1.6)*(.5-band*.4)
            pp.z+=math.sin(v*math.pi)*1.1-v*v*1.5
            pp.z+=.18*math.sin(u*math.pi*9)*math.sin(math.pi*v)*(.3+.7*v)
            return tuple(pp)
        grid_shell(tissue,roof,60,20,.10)
        for j in range(9):
            u=j/8
            points=[roof(u,v/10) for v in range(11)]
            tube(ribs,points,lambda t:.11*(1-t)+.035,9,22,.12)
        for v in (0,1):tube(wood,[roof(i/14,v) for i in range(15)],.18 if v else .26,12,36,.13)
        # Fine branching vascular strands, in geometry, not only paint.
        for j in range(7):
            for s in (-1,1):
                u=(j+.5)/8
                pts=[roof(max(.015,min(.985,u+s*v*.055)),v) for v in (.25,.43,.62,.83,1)]
                tube(ribs,pts,.024,6,12,.0)
    # Open branching throat supports a broad asymmetric living crown above passage.
    crown_base=Vector((-8.6,-.4,8.3))
    crown_tips=[Vector(v) for v in [(-12.2,-1.4,17.8),(-8.0,-5.6,22.1),(-1.7,-4.8,23.1),(5.0,1.5,21.0),(10.8,8.1,16.9)]]
    def crown(u,v):
        q=u*(len(crown_tips)-1);i=min(int(q),len(crown_tips)-2);t=q-i
        tip=crown_tips[i].lerp(crown_tips[i+1],t)
        tip.z-=.8*math.sin(t*math.pi)
        p=crown_base.lerp(tip,v)
        p.y-=2.6*math.sin(v*math.pi)*(1+.35*math.sin(u*math.pi*3))
        p.z+=.40*math.sin(v*math.pi)+.11*math.sin(u*math.pi*28)*v*v
        return tuple(p)
    for sector in range(4):
        def crown_panel(u,v,sector=sector):
            start=.32+.11*math.sin(u*math.pi)**.7
            return crown((sector+u)/4,start+v*(1-start))
        grid_shell(tissue,crown_panel,24,24,.085)
        tube(wood,[crown((sector+u/20)/4,1) for u in range(21)],.12,10,32,.12)
    for ray in range(17):
        u=ray/16
        points=[crown(u,v/24) for v in range(25)]
        major=ray%4==0
        rr=(lambda t:.30*(1-t)+.07) if major else (lambda t:.12*(1-t)+.025)
        ps=tube(wood if major else ribs,points,rr,12 if major else 8,40,.14)
        if major:bark_plates(plates,ps,rr,22,.15)
        for side in (-1,1):
            for split in (.48,.69):
                pp=[crown(max(.002,min(.998,u+side*(v-split)*.065)),v) for v in (split,split+.10,split+.20,split+.30)]
                tube(ribs,pp,.023,6,16,.05)
    # Smaller rear cowl grows out of the opposite arch and completes roof depth.
    rear_base=Vector((9.3,4.9,9.1))
    rear_tips=[Vector(p) for p in [(-5.5,7.4,17.9),(.3,10.2,20.2),(7.2,10.9,19.0),(13.4,8.5,14.9)]]
    def rear(u,v):
        q=u*3;i=min(int(q),2);f=q-i;tip=rear_tips[i].lerp(rear_tips[i+1],f)
        tip.z-=.55*math.sin(f*math.pi)
        p=rear_base.lerp(tip,v)+Vector((0,1.7*math.sin(v*math.pi),.4*math.sin(v*math.pi)))
        return tuple(p)
    for sector in range(3):
        def rear_panel(u,v,sector=sector):
            start=.43+.06*math.sin(u*math.pi)
            return rear((sector+u)/3,start+(1-start)*v)
        grid_shell(tissue,rear_panel,20,20,.09)
    for ray in range(13):
        major=ray%4==0
        tube(wood if major else ribs,[rear(ray/12,v/22) for v in range(23)],(lambda t:.26*(1-t)+.055) if major else (lambda t:.10*(1-t)+.021),10 if major else 7,32,.12)
    tube(wood,[rear(u/36,1) for u in range(37)],.13,11,44,.1)
    # Sturdy lateral perch is part of the arch, its upper surface is not a separate floating prop.
    perch=[(-7,.5,10),(-4.8,-.6,13.2),(-1.5,-1.5,14.2),(2.1,-1.6,14.0),(4.4,-.7,15.2)]
    ps=tube(wood,perch,lambda t:.58*(1-t)+.23,16,44,.16,1.05);bark_plates(plates,ps,lambda t:.58*(1-t)+.23,24,.35)
    for j in range(22):
        t=R.uniform(.17,.82);p=paths[j%2][int(t*(len(paths[j%2])-1))]
        p=p+Vector((R.uniform(-.3,.3),-.7,.25))
        ellipsoid(organs,p,(.13,.11,.26),12,8,j)
    for j in range(28):
        t=R.uniform(.25,.77);p=paths[j%2][int(t*(len(paths[j%2])-1))]
        length=R.uniform(.6,2.5)
        pts=[p,p+Vector((.1,-.16,-length*.3)),p+Vector((-.2,-.2,-length*.73)),p+Vector((.06,-.26,-length))]
        tube(tendrils,pts,lambda t:.07*(1-t)+.015,7,16,.18)
        for k in range(3):
            a=pts[1].lerp(pts[-1],k/3);ellipsoid(tendrils,a,(.10,.045,.19),8,6,j)

def sails():
    roots((0,0,0),2.2,1.15,'Sail_shared_holdfast',9)
    specs=[((-.65,0,.45),6.7,3.15,-.18,.0),((1.05,.55,.4),4.75,2.5,.35,.54),((-.85,.8,.35),3.5,1.95,-.50,-.61)]
    for index,(base,h,w,lean,angle) in enumerate(specs):
        base=Vector(base); ca=math.cos(angle);sa=math.sin(angle)
        skin=group('Sail_%s_pleated_blade'%index,'sail_tissue',base)
        rib=group('Sail_%s_support_ribs'%index,'sail_rib',base)
        stem=group('Sail_%s_live_stem'%index,'mineral_bark',base)
        def shape(u,v):
            # Curved cowl fan with pleats, narrower heel and rolled tips.
            width=w*math.sin(math.pi*v*.72)**.85
            x=(u-.20)*width + (lean*.42+.20)*v*v*h
            z=v*h - (u**1.25)*h*.29*v**1.2 + .18*math.sin(u*math.pi*4)*v**3
            y=(.30*math.sin(u*math.pi)+.067*math.sin(u*math.pi*14))*math.sin(v*math.pi*.86)*w
            y+=v*v*.3*w+u*u*v*.18
            return tuple(base+Vector((x*ca-y*sa,x*sa+y*ca,z)))
        grid_shell(skin,shape,56,40,.045)
        for k in range(9):
            u=k/8
            tube(rib,[shape(u,j/16) for j in range(17)],lambda t:.055*(1-t)+.013,8,36,.08)
        for v in (.98,):tube(rib,[shape(j/24,v) for j in range(25)],.035,9,40,.07)
        for vein in range(8):
            u=vein/8
            for height in (.27,.44,.61,.78):
                points=[shape(u+t*.11,height+t*.17) for t in (0,.25,.5,.75,1)]
                tube(rib,points,.009,6,10,0)
        pts=[tuple(base-Vector((0,0,.35))),shape(0,.25),shape(0,.56),shape(0,.83),shape(0,1)]
        ps=tube(stem,pts,lambda t:.24*(1-t)+.035,13,42,.18)
        bark_plates(group('Sail_%s_stem_scales'%index,'bark_ridge',base),ps,lambda t:.24*(1-t)+.035,22,.115)
        for k in range(22):
            u=R.random();v=R.uniform(.26,.94)
            p=Vector(shape(u,v))+Vector((0,-.025,.025))
            ellipsoid(group('Sail_%s_condensation'%index,'shore_inner',base),p,(.032,.025,.044),8,6,k)
        for k in range(4):
            p=Vector(shape(.06,.08+k*.14))+Vector((0,-.09,0))
            ellipsoid(group('Sail_%s_cyan_axil'%index,'cyan_organ',base),p,(.043,.033,.083),10,7,k)

def pods():
    wood=group('Pods_crooked_branch_network','mineral_bark');ridge=group('Pods_bark_scales','bark_ridge')
    roots((0,0,0),1.8,1.1,'Pods_holdfast',8)
    trunk=[(0,0,.0),(-.25,.06,.8),(.13,.1,1.6),(-.05,.3,2.25),(.25,.35,2.9)]
    ps=tube(wood,trunk,lambda t:.27*(1-t)+.06,15,34,.22);bark_plates(ridge,ps,lambda t:.27*(1-t)+.06,24,.13)
    # Fruit centres/scale/state, deliberately uneven branching and maturity.
    specs=[((-1.05,-.14,2.15),.61,'ripe'),((.70,-.12,2.62),.73,'open'),
           ((1.44,.50,1.68),.56,'ripe'),((-.52,.56,3.22),.52,'closed'),
           ((.30,.32,3.76),.38,'closed'),((-1.37,.77,1.16),.44,'open'),
           ((.00,-.72,1.32),.40,'ripe'),((.94,1.00,3.00),.46,'ripe')]
    for k,(pos,s,state) in enumerate(specs):
        c=Vector(pos)
        base=Vector((-.08,.15,max(.6,c.z*.45)))
        stem=[base,base.lerp(c,.55)+Vector((-.15,0,.22)),c+Vector((0,0,-s*.9))]
        ps=tube(wood,stem,lambda t:.11*(1-t)+.035,11,22,.19)
        bark_plates(ridge,ps,lambda t:.11*(1-t)+.035,12,.07)
        skin=group('Pods_'+str(k)+'_'+state+'_waxy_shell','unripe_pod' if state=='closed' else 'wax_pod',c-Vector((0,0,s)))
        calyx=group('Pods_fruit_seams_and_calyces','sail_rib')
        def fruit(u,v):
            a=u*TAU
            # Lobed pear shell with shoulders, tapering mouth, small twisting seams.
            radius=s*(math.sin(math.pi*v)**.83)*(.63+.23*v)*(1+.105*math.cos(a*7+v*.3)+.035*math.sin(a*3+v*7))
            radius+=s*.012
            return tuple(c+Vector((radius*math.cos(a)+s*.09*math.sin(math.pi*v),radius*.78*math.sin(a),s*(v*2-1))))
        if state!='open':
            grid_shell(skin,fruit,42,28,.035)
            for j in range(7):
                points=[fruit(j/7,v/16) for v in range(17)]
                tube(calyx,points,lambda t:.015+s*.019*math.sin(t*math.pi),7,24,.06)
            if state=='ripe':
                # Small exposed amber windows sit between skin folds; bulk stays waxy.
                glow=group('Pods_local_amber_fissures','amber_organ')
                for j in (0,2,4):
                    u=(j+.43)/7
                    pts=[fruit(u,v) for v in (.34,.45,.57,.67)]
                    tube(glow,pts,s*.018,7,14,.12)
        else:
            # Five genuinely open thick valves, curled back with a dark chamber below.
            inner=group('Pods_'+str(k)+'_inner_valves','inner_pod',c-Vector((0,0,s)))
            for petal in range(5):
                angle=petal*TAU/5
                def valve(u,v,angle=angle):
                    a=angle+(u-.5)*TAU/5*.88
                    radius=s*(.055+.68*math.sin(v*math.pi*.78)+.38*v*v)
                    z=s*(-1+1.94*v-.70*v**4)+s*.09*math.cos((u-.5)*math.pi*2)*v**4
                    return tuple(c+Vector((math.cos(a)*radius,math.sin(a)*radius*.80,z)))
                grid_shell(skin,valve,10,24,.06,back_target=inner)
                tube(calyx,[valve(0,v/16) for v in range(17)],s*.031,8,24,.12)
                tube(calyx,[valve(1,v/16) for v in range(17)],s*.031,8,24,.12)
            for seed in range(5):
                a=seed*TAU/5;sc=s*.145
                ellipsoid(group('Pods_open_chamber_seeds','amber_organ'),c+Vector((math.cos(a)*s*.21,math.sin(a)*s*.15,-s*.08)),(sc,sc*.8,sc*1.4),12,9,k)
        if state!='open':
            for j in range(5):
                a=j*TAU/5
                p=Vector(fruit(j/5,.86))
                tip=c+Vector((math.cos(a)*s*.065,math.sin(a)*s*.055,s*1.18))
                tube(calyx,[p,p.lerp(tip,.55)+Vector((math.cos(a)*s*.05,math.sin(a)*s*.05,0)),tip],lambda t:s*.029*(1-t)+.004,7,10,.1)
        # Stem-grown pointed crown reinforces pod identity instead of glass bulb neck.
        for j in range(5):
            a=j*TAU/5
            p=c+Vector((math.cos(a)*s*.18,math.sin(a)*s*.15,-s*.90))
            tube(calyx,[p,c+Vector((math.cos(a)*s*.29,math.sin(a)*s*.21,-s*.50))],lambda t:s*.035*(1-t)+.003,7,8,.1)
    # Cracked fallen husks around the contact zone.
    litter=group('Pods_shed_wax_fragments','unripe_pod')
    for k in range(13):
        a=R.random()*TAU;r=R.uniform(.45,1.65);c=Vector((math.cos(a)*r,math.sin(a)*r,.08))
        def shard(u,v):return tuple(c+Vector(((u-.5)*.23,(v-.5)*.33,.055*math.sin(u*math.pi)+.09*v*v)))
        grid_shell(litter,shard,5,6,.025)

def cups():
    outer=group('Cups_waxy_outer_bowls','shore_outer');inner=group('Cups_wet_concave_interiors','shore_inner')
    lips=group('Cups_thick_folded_lips','shore_lip');veins=group('Cups_raised_inner_veins','sail_rib')
    stems=group('Cups_flaring_base_supports','damp_root')
    specs=[((-.65,-.1,0),1.0,2.55,-.28),((1.30,.67,0),.70,1.50,.20),((-1.75,.93,0),.53,1.34,.55)]
    for k,(base,s,h,turn) in enumerate(specs):
        c=Vector(base)
        roots(base,1.12*s,h*.38,'Cups_'+str(k)+'_root_pad',7)
        def bowl(u,v):
            a=u*TAU+turn
            r=s*(.14+1.66*v**.67)*(1+.13*math.sin(a*3+.6)+.07*math.sin(a*5))
            # Off-centre throat, folded saddle rim and a single dipped drainage fold.
            drain=math.exp(-((math.atan2(math.sin(a+.7),math.cos(a+.7)))/.22)**2)
            z=.18+h*(.17+.65*v) + s*(.49*math.sin(a+.3)+.16*math.sin(a*3))*v*v - s*.36*drain*v**6
            z+=s*.027*math.sin(a*36)*(v**1.3)
            return tuple(c+Vector((r*math.cos(a)+s*.32*v*v,r*.80*math.sin(a),z)))
        grid_shell(outer,bowl,88,30,.08*s,back_target=inner)
        def bowl_inner(u,v):
            p=Vector(bowl(u,v));return tuple(p+Vector((0,0,.042*s)))
        tube(lips,[bowl(j/100,1) for j in range(101)],lambda t:s*(.082+.024*math.sin(t*TAU*6)),12,120,.08,.83)
        for rib in range(20):
            u=rib/20
            tube(veins,[bowl_inner(u,v) for v in (.05,.19,.37,.59,.79,.97)],lambda t:s*(.029*(1-t)+.007),7,20,.10)
            if rib%3==0:
                a=u*TAU+turn;off=Vector((math.cos(a)*.115,math.sin(a)*.115,-.09))*s
                tube(stems,[tuple(c+Vector((0,0,.05))),tuple(Vector(bowl(u,.18))+off),tuple(Vector(bowl(u,.5))+off),tuple(Vector(bowl(u,.85))+off)],lambda t:s*(.095*(1-t)+.025),11,26,.18)
        # A rolled channel grows through the lowered lip to release collected moisture.
        p=Vector(bowl(((-.7-turn)%TAU)/TAU,1))
        tube(lips,[p,p+Vector((.20,-.20,-.03))*s,p+Vector((.26,-.3,-.23))*s],lambda t:s*(.080*(1-t)+.02),10,16,.10)
        tube(stems,[tuple(c),tuple(c+Vector((-.10,.10,h*.25))),bowl(.2,.18)],lambda t:s*(.22*(1-t)+.13),14,18,.22)
        for j in range(8):
            u=R.random();v=R.uniform(.45,.95)
            p=Vector(bowl_inner(u,v))+Vector((0,0,s*.03))
            ellipsoid(group('Cups_beaded_condensation','shore_inner'),p,(s*.035,s*.042,s*.026),8,6,j)

def mat():
    fibers=group('Mat_interlaced_mineral_root_fibres','damp_root')
    bright=group('Mat_fine_secondary_mycelium','sail_rib')
    stone=group('Mat_embedded_mineral_grains','mineral_grain')
    film=group('Mat_irregular_nutrient_pockets','nutrient_film')
    light=group('Mat_sparse_linked_cyan_nodes','cyan_organ')
    def ground(x,y):return .005
    paths=[]
    for j in range(13):
        a=R.uniform(0,TAU);r=R.uniform(1.2,2.6)
        p=[(R.uniform(-.7,.7),R.uniform(-.5,.5),.04),
           (math.cos(a)*r*.35,math.sin(a)*r*.28,.12),
           (math.cos(a+.17)*r*.73,math.sin(a+.17)*r*.6,.08),
           (math.cos(a)*r,math.sin(a)*r*.78,.015)]
        tube(fibers,p,lambda t:.085*(1-t)+.018,9,30,.24,.72)
        paths.append(p)
    # Fibrous bridges are curved into irregular islands, leaving true bare gaps.
    for j in range(150):
        a=R.random()*TAU;r=R.random()**.7*2.5;x=math.cos(a)*r;y=math.sin(a)*r*.75
        if (x-.35)**2+(y+.15)**2<.22:continue
        length=R.uniform(.25,.93);angle=R.random()*TAU
        pts=[]
        for k in range(5):
            u=k/4
            xx=x+math.cos(angle)*u*length;yy=y+math.sin(angle)*u*length+.08*math.sin(u*math.pi)
            pts.append((xx,yy,ground(xx,yy)+.004))
        tube(bright,pts,lambda t:.006+.004*math.sin(t*math.pi),6,12,.1,.55)
        if j%2==0:
            cross=[]
            for k in range(5):
                u=k/4;xx=x+math.cos(angle+.7)*u*length*.6;yy=y+math.sin(angle+.7)*u*length*.6
                cross.append((xx,yy,ground(xx,yy)+.006))
            tube(bright,cross,.006,5,10,0,.55)
    # Connected lace islands supply genuine fibrous coverage between the large roots.
    for island in range(13):
        a=R.random()*TAU;r=R.uniform(.65,2.2);c=Vector((math.cos(a)*r,math.sin(a)*r*.72,.018))
        radius=R.uniform(.25,.53);anchors=[]
        for k in range(8):
            ang=k*TAU/8+R.uniform(-.10,.10);rr=radius*R.uniform(.72,1.12)
            anchors.append(c+Vector((math.cos(ang)*rr,math.sin(ang)*rr,0)))
        for k,tip in enumerate(anchors):
            tube(bright,[tuple(c),tuple(c.lerp(tip,.45)+Vector((.02,-.01,-.007))),tuple(tip)],.0045,5,9,0,.6)
            nxt=anchors[(k+1)%8]
            for level in (.30,.58,.84):
                p=c.lerp(tip,level);q=c.lerp(nxt,level)
                mid=p.lerp(q,.5).lerp(c,.09)
                tube(bright,[tuple(p),tuple(mid),tuple(q)],.0035,5,7,0,.6)
    for j in range(21):
        a=R.random()*TAU;r=R.uniform(.5,2.25);x=math.cos(a)*r;y=math.sin(a)*r*.72
        if (x-.35)**2+(y+.15)**2<.33:continue
        sx=R.uniform(.13,.45);sy=R.uniform(.12,.35)
        def patch(u,v):
            a=u*TAU;rr=.04+v*(1+.13*math.sin(a*5+j))
            xx=x+math.cos(a)*sx*rr;yy=y+math.sin(a)*sy*rr
            return (xx,yy,ground(xx,yy)+.014+.025*(1-v*v))
        grid_shell(film,patch,24,5,.018)
        if j%3==0:ellipsoid(light,(x,y,ground(x,y)+.065),(.043,.029,.025),10,7,j)
    for j in range(110):
        a=R.random()*TAU;r=R.random()**.6*2.45;x=math.cos(a)*r;y=math.sin(a)*r*.75
        if (x-.35)**2+(y+.15)**2<.3:continue
        s=R.uniform(.025,.10)
        ellipsoid(stone,(x,y,ground(x,y)),(s,s*R.uniform(.65,1.2),s*R.uniform(.5,1.1)),7,5,j)

def spores():
    log=group('Spores_decaying_host_root','decaying_root');bark=group('Spores_root_delamination','mineral_bark')
    path=[(-2.2,0,.06),(-1.4,.1,.28),(-.5,-.10,.45),(.4,.10,.5),(1.4,.0,.34),(2.2,.28,.12)]
    ps=tube(log,path,lambda t:.14+.18*math.sin(t*math.pi)**.6,15,48,.25,.77)
    bark_plates(bark,ps,lambda t:.14+.18*math.sin(t*math.pi)**.6,31,.18)
    for j in range(5):
        x=-1.7+j*.8
        tube(log,[(x,.0,.22),(x+.2,.45,.18),(x+.6,.82,-.04)],lambda t:.11*(1-t)+.018,9,18,.3)
    specs=[((-1.45,-.06,.34),.70,-.35),((-.75,-.05,.49),.95,-.14),((.06,.07,.58),1.03,.18),((.75,.07,.54),.92,.10),((1.42,.16,.38),.67,.46),((-.30,.40,.47),.65,2.30)]
    for k,(base,s,turn) in enumerate(specs):
        c=Vector(base)
        shell=group('Spores_'+str(k)+'_porous_upper_crust','spore_crust',c)
        gills=group('Spores_'+str(k)+'_accordion_lamellae','soft_gills',c)
        edge=group('Spores_'+str(k)+'_mineralized_lip','spore_crust',c)
        def fan(u,v):
            a=(u-.5)*math.pi*1.08+turn
            r=s*(.065+v*1.05)
            x=r*math.sin(a);y=-r*math.cos(a)
            z=s*(.10+v*1.22-v*v*.25)+.014*s*math.sin(u*math.pi*42)*v
            z+=s*.08*math.sin(u*math.pi*5+.5)*v**3
            return tuple(c+Vector((x,y,z)))
        # Perforations are actual holes in the outer 30% of the hard crust.
        holes=set()
        for j in range(22):
            ii=R.randrange(3,61);jj=R.randrange(13,21)
            holes.add((ii,jj))
            if j%3==0:holes.update(((ii+1,jj),(ii-1,jj),(ii,jj+1),(ii,jj-1)))
        grid_shell(shell,fan,64,24,.075*s,mask=lambda i,j:(i,j) not in holes)
        # Deep pale gills hang under the crust; every ray is a thick curved ribbon.
        for j in range(35):
            u=(j+.5)/35
            def gill(a,v,u=u):
                p=Vector(fan(u,.07+v*.88))
                depth=s*.43*math.sin(v*math.pi*.87)
                p.z-=.055*s + math.sin(a*math.pi)*depth
                ang=(u-.5)*math.pi*1.08+turn
                p.x+=(a-.5)*s*.016*math.cos(ang);p.y+=(a-.5)*s*.016*math.sin(ang)
                return tuple(p)
            grid_shell(gills,gill,3,18,.013*s)
        tube(edge,[fan(j/70,1) for j in range(71)],lambda t:s*(.045+.008*math.sin(t*TAU*17)),10,100,.11)
        for grain in range(22):
            u=R.uniform(.05,.95);v=R.uniform(.71,.98);p=Vector(fan(u,v))+Vector((0,0,.035*s))
            size=R.uniform(.012,.035)*s
            ellipsoid(edge,p,(size,size*.8,size*.4),7,5,grain)
        tube(log,[tuple(c-Vector((0,0,.18))),tuple(c),fan(.5,.28)],lambda t:s*(.16*(1-t)+.06),11,16,.16)
        for j in range(3):
            p=Vector(fan(.25+j*.23,.87))+Vector((0,-.012,.04))
            ellipsoid(group('Spores_sparse_rim_organs','cyan_organ'),p,(s*.031,s*.045,s*.032),10,7,j)

BUILDERS={'canopy':canopy,'sails':sails,'pods':pods,'cups':cups,'mat':mat,'spores':spores}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def inspect_glb(path):
    data=path.read_bytes();n=int.from_bytes(data[12:16],'little');g=json.loads(data[20:20+n]);acc=g['accessors']
    primitives=[p for m in g.get('meshes',[]) for p in m['primitives']]
    return {'file':str(path.relative_to(ROOT)).replace('\\','/'),'bytes':len(data),'sha256':sha(path),
        'triangles':sum(acc[p['indices']]['count']//3 for p in primitives),'vertices':sum(acc[p['attributes']['POSITION']]['count'] for p in primitives),
        'meshNodes':len(g.get('meshes',[])),'materials':len(g.get('materials',[])),'images':len(g.get('images',[])),
        'normalMappedMaterials':sum('normalTexture' in m for m in g.get('materials',[])),
        'alphaModes':[m.get('alphaMode','OPAQUE') for m in g.get('materials',[])],
        'missingUV':sum('TEXCOORD_0' not in p['attributes'] for p in primitives),
        'missingNormals':sum('NORMAL' not in p['attributes'] for p in primitives),
        'animations':len(g.get('animations',[])),'skins':len(g.get('skins',[]))}

def build(name):
    global GROUPS,R
    R=random.Random(SEED+list(BUILDERS).index(name)*101);GROUPS={}
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    parent=bpy.data.objects.new(name+'_root',None);bpy.context.collection.objects.link(parent)
    parent['units']='metres';parent['origin']='ground contact at centre; Blender Z up -> glTF/Godot Y up'
    parent['authoring']='Original local deterministic sculptural mesh kit, seed '+str(SEED)
    BUILDERS[name]()
    objects=[g.object(parent) for g in GROUPS.values()];objects=[o for o in objects if o]
    bpy.context.view_layer.update()
    vs=[o.matrix_local@v.co for o in objects for v in o.data.vertices]
    low=[min(v[k] for v in vs) for k in range(3)];high=[max(v[k] for v in vs) for k in range(3)]
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=False,export_extras=True,export_texcoords=True,export_normals=True)
    report=inspect_glb(path)
    report.update({'family':name,'boundsBlenderXYZ':{'min':low,'max':high,'size':[high[k]-low[k] for k in range(3)]},
                   'sourceBlend':str((SOURCE/(name+'.blend')).relative_to(ROOT)).replace('\\','/'),'sourceBlendSha256':sha(SOURCE/(name+'.blend')),
                   'seed':SEED+list(BUILDERS).index(name)*101,'sourceScriptSha256':sha(Path(__file__)),
                   'blender':bpy.app.version_string,'license':'Original project-authored procedural geometry and raster PBR textures. No external models or texture photographs. Concept references supplied by project; not embedded.',
                   'status':'EXPORTED_STRUCTURAL_CANDIDATE; awaiting offline GLB visual review and engine integration'})
    assert report['triangles']>1000 and report['missingUV']==0 and report['missingNormals']==0
    (OUT/(name+'.manifest.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
    print('FLORA_EXPORTED '+json.dumps(report),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--families',default='canopy,sails')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    init_materials()
    for name in args.families.split(','):build(name)
