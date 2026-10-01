"""Listening Reefs anatomy. Isolated CPU Blender; original rigs stay intact.

Reuses the project's tested loft/sweep, atlas bake and tangent repair helpers.
All new sources/maps and evidence are confined to this package's ownership.
"""
import ast, bpy, bmesh, math, json, hashlib, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
MAPS = SOURCE / 'maps'
EVID = ROOT / 'evidence/alien-renewal-20260930T200644Z/biological'
OUT = ROOT / 'godot/assets/visual_fauna'
PREVIOUS = ROOT / 'art-source/creature_upgrade'
for directory in (MAPS, EVID): directory.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(SOURCE))
from repair_tangents import repair_singular_tangents

# Import only reusable functions: the historical builder's top-level jobs are
# deliberately not executed and its sources/output directories are untouched.
helper_source = PREVIOUS / 'build_finish_creatures.py'
helpers = {'xyz', 'linear', 'soft_noise', 'append', 'loft', 'sweep', 'pad', 'build_meshes', 'bake'}
tree = ast.parse(helper_source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in helpers], type_ignores=[]), str(helper_source), 'exec'))
TAU = math.tau
parts = {}
materials = {}


def tissue(part, vertices, faces, thickness):
    # A single two-sided sheet, rather than doubled opaque shell geometry.
    append(part, vertices, faces, 'membrane', thickness=thickness)


def plate(part, z0, z1, width, base, height, index, front=False):
    """Thin faceted bearing lamina with a dark undercut and a worn copper rim."""
    vertices = []; faces = []; rows = 11; columns = 29
    for lower in (False, True):
        for k in range(rows):
            t = k / (rows - 1)
            z = z0 + (z1 - z0) * t
            w = width * (.90 + .10 * math.sin(math.pi * (.13 + .78*t)))
            longitudinal = 1.0 - .11*t + .036*math.sin(math.pi*t)
            for j in range(columns):
                u = j / (columns - 1) * 2 - 1
                # Deliberate shoulder creases break the former padded dome.
                contour = float(np.interp(abs(u), [0, .28, .72, .94, 1], [1, .965, .70, .25, 0]))
                wave = .015 * math.sin(u*6.1 + index*.81) + .006 * math.sin(u*17+index)
                point = Vector((u*w, base + height*contour*longitudinal, z + wave))
                point.y += .009*noise.noise(Vector((point.x*5, z*5, index)))
                if lower: point.y -= .035 if front else .043
                vertices.append(tuple(point))
    count = rows*columns
    for lower in range(2):
        for k in range(rows-1):
            for j in range(columns-1):
                a = lower*count+k*columns+j
                f = (a, a+columns, a+columns+1, a+1)
                faces.append(tuple(reversed(f)) if lower else f)
    append(part, vertices, faces, 'mineral')
    rim = []
    for k in (0, rows-1):
        for j in range(columns-1):
            a = k*columns+j; rim.append((a, a+1, a+1+count, a+count))
    for k in range(rows-1):
        for j in (0, columns-1):
            a = k*columns+j; rim.append((a, a+count, a+count+columns, a+columns))
    append(part, vertices, rim, 'worn_edge', smooth=False)
    # A narrow upper abrasion bevel catches dawn along the feathered edge.
    leading = [Vector(vertices[j]) for j in range(columns)]
    sweep(part, leading, [.011]*columns, 'worn_edge', sides=6, detail=1, flatten=.45, grain=.001)


def veyra():
    loft('Body', [(0,.36,-1.39,.10,.11),(0,.47,-1.03,.55,.21),(0,.49,-.35,.80,.24),
                 (0,.49,.41,.84,.25),(0,.39,1.16,.53,.18),(0,.34,1.49,.025,.024)],
         'skin', steps=35, rings=28, grain=.003, flat_sole=.14)
    for i, (z0,z1,w,b,h) in enumerate([(-1.35,-.70,.57,.62,.31),(-.91,-.15,.79,.59,.43),
                                      (-.34,.43,.91,.56,.47),(.24,.99,.90,.51,.45),(.80,1.49,.63,.40,.35)]):
        plate('Body', z0,z1,w,b,h,i)
    loft('Head', [(0,.32,-2.08,.075,.045),(0,.38,-1.88,.27,.07),(0,.47,-1.54,.38,.13),
                 (0,.43,-1.17,.28,.13)], 'skin', steps=23, rings=24, grain=.002)
    plate('Head', -2.04,-1.50,.28,.43,.18,8,front=True)
    plate('Head', -1.72,-1.19,.37,.48,.18,9,front=True)
    for side in (-1,1):
        sweep('Head', [(side*.23,.43,-1.92),(side*.32,.49,-1.75),(side*.36,.50,-1.54)],
              [.020,.024,.012], 'eyes', sides=10, flatten=.48)
        sweep('Head', [(side*.24,.32,-1.80),(side*.31,.27,-2.02),(side*.26,.25,-2.17)],
              [.047,.026,.002], 'worn_edge', sides=10)
        sweep('Head', [(side*.34,.50,-1.50),(side*.47,.54,-1.73),(side*.49,.59,-1.97)],
              [.014,.010,.002], 'signal', sides=8)
        for k in range(3):
            label = 'L' if side<0 else 'R'
            hip = Vector((side*.78,.47,-.77+k*.77))
            knee = hip + Vector((side*.5,-.14,.12))
            ankle = knee + Vector((side*.015,-.61,.17))
            leg = f'Leg_{label}_{k}'; shin = f'Shin_{label}_{k}'; foot = f'Foot_{label}_{k}'
            sweep(leg, [hip,hip+Vector((side*.19,0,0)),hip+Vector((side*.36,-.07,.06)),knee],
                  [.107,.130,.103,.077], 'skin', sides=12, flatten=.76, grain=.002)
            sweep(leg, [hip+Vector((0,.073,0)),hip+Vector((side*.21,.095,.012)),knee+Vector((0,.030,-.020))],
                  [.052,.080,.024], 'mineral', sides=10, flatten=.40)
            pad(leg, knee, (.085,.072,.09), 'skin', segments=16)
            sweep(shin, [knee,knee+Vector((side*.07,-.17,.06)),knee+Vector((side*.035,-.42,.14)),ankle],
                  [.077,.057,.035,.055], 'skin', sides=12, flatten=.75)
            sweep(shin, [knee+Vector((0,.049,-.018)),knee+Vector((side*.040,-.25,.015)),ankle+Vector((0,.023,.018))],
                  [.047,.030,.018], 'mineral', sides=10, flatten=.35)
            pad(foot, ankle+Vector((0,-.050,.022)), (.125,.065,.175), 'skin', sole=ankle.y-.115, segments=24)
            for digit in (-1,0,1):
                root=ankle+Vector((digit*.067,-.043,-.028))
                tip=ankle+Vector((digit*.094,-.082,-.22-(.025 if digit==0 else 0)))
                sweep(foot,[root,(root+tip)*.5+Vector((0,.009,0)),tip],[.037,.026,.004], 'skin', sides=8)
                sweep(foot,[tip+Vector((0,.015,.018)),tip+Vector((0,-.025,-.033))],[.014,.001], 'worn_edge', sides=7)


def morrow():
    loft('Body', [(0,-.53,-1.43,.03,.06),(0,-.50,-1.13,.50,.15),(0,-.49,-.58,.98,.19),
                 (0,-.50,.22,1.10,.20),(0,-.54,.94,.62,.15),(0,-.56,1.21,.025,.025)],
         'skin', steps=35, rings=32, flat_sole=-.70)
    loft('Body', [(0,-.27,-1.11,.075,.08),(0,-.06,-.65,.63,.36),(0,-.02,-.08,.82,.43),
                 (0,-.10,.61,.77,.35),(0,-.28,1.09,.09,.07)], 'skin', steps=29, rings=28, grain=.004)
    for layer,(r0,r1) in enumerate([(.25,.53),(.45,.75),(.66,.96),(.85,1.10)]):
        vertices=[];faces=[];rows=8;sides=72
        for lower in (False,True):
            for k in range(rows):
                t=k/(rows-1);r=r0+(r1-r0)*t
                for j in range(sides):
                    a=j/sides*TAU
                    scallop=1+.030*math.sin(a*7+layer*.43)+.013*math.sin(a*19)
                    x=math.cos(a)*.98*r*scallop;z=.12+math.sin(a)*1.07*r*scallop
                    h=.09+.57*max(0,1-min(r,1)**2.1)**.62 + .036*(1-t)
                    h+=.021*math.sin(a*6.0+layer*.31)*r
                    p=Vector((x,h-(.034 if lower else 0),z))+soft_noise((x,h,z),.004)
                    vertices.append(tuple(p))
        count=rows*sides
        for lower in range(2):
            for k in range(rows-1):
                for j in range(sides):
                    a=lower*count+k*sides+j;b=lower*count+k*sides+(j+1)%sides
                    f=(a,b,b+sides,a+sides);faces.append(tuple(reversed(f)) if lower else f)
        append('Body',vertices,faces,'mineral')
        rim=[]
        for k in (0,rows-1):
            for j in range(sides):
                a=k*sides+j;b=k*sides+(j+1)%sides;rim.append((a,a+count,b+count,b))
        append('Body',vertices,rim,'worn_edge',smooth=False)
    for side in (-1,1):
        sweep('Body',[(side*.35,-.10,-.91),(side*.46,-.04,-1.10),(side*.54,.12,-1.35),(side*.51,.24,-1.43)],
              [.055,.046,.025,.009],'skin',sides=12)
        pad('Body',(side*.51,.235,-1.445),(.031,.028,.043),'eyes',segments=18)
        for k in range(9):
            z=-.86+k*.215;x=side*(.63+.40*math.sin(k/8*math.pi))
            sweep('Body',[(x,-.48,z),(x+side*.07,-.59,z+.018),(x+side*.068,-.67,z-.025)],
                  [.025,.030,.007],'skin',sides=7)
    for k in range(7):
        node=bpy.data.objects[f'CrownFrond_{k}'];vertices=[];faces=[];depth=[]
        length=.96+.16*math.sin(k*1.13+.5);width=.19+.033*(k%3);rows=26;cols=11
        def point(t,u):
            profile=math.sin(math.pi*t)**.80+.012
            lobe=1+.065*math.sin(t*math.pi*8+k*.21)*abs(u)
            return Vector((u*width*profile*lobe,.07+length*t,.43*t*t+.042*u*u*math.sin(math.pi*t)))
        def world(p):
            v=node.matrix_world@xyz(p);return (v.x,v.z,-v.y)
        for i in range(rows):
            t=i/(rows-1)
            for j in range(cols):
                u=j/(cols-1)*2-1;vertices.append(world(point(t,u)))
                depth.append(.16+.42*math.exp(-(u/.15)**2)+.12*abs(u)**6)
        for i in range(rows-1):
            for j in range(cols-1):a=i*cols+j;faces.append((a,a+1,a+cols+1,a+cols))
        tissue(f'CrownFrond_{k}',vertices,faces,depth)
        sweep(f'CrownFrond_{k}',[world(point(t,0)) for t in np.linspace(0,1,8)],
              [.018*(1-t)+.0015 for t in np.linspace(0,1,8)],'skin',sides=8,detail=2)
        for t in (.27,.43,.60,.76):
            for side in (-1,1):
                sweep(f'CrownFrond_{k}',[world(point(t,0)),world(point(t+.05,side*.55)),world(point(t+.07,side*.94))],
                      [.005,.004,.001],'worn_edge',sides=6,detail=2)
        tip=Vector(world(point(.98,0)))
        sweep(f'CrownFrond_{k}',[tip-Vector((0,.06,0)),tip],[.010,.002],'signal',sides=7)


def wing_point(side,s,t):
    leading=Vector((side*(.36+2.42*s),.04+1.30*s-.58*s*s,-.08+.26*s))
    chord=(.10+1.54*math.sin(math.pi*s)**.64)*(1-.15*s)
    bay=math.sin(s*math.pi*6)**2
    return leading+Vector((side*.075*t,-.14*t*t-.045*bay*math.sin(math.pi*t),chord*t*(.94+.06*bay)))


def aeral():
    loft('Body',[(0,-.13,-1.12,.025,.04),(0,-.02,-.93,.20,.17),(0,-.03,-.58,.29,.30),
                 (0,-.21,-.10,.29,.38),(0,-.37,.43,.16,.21),(0,-.39,.94,.010,.014)],
         'skin',steps=35,rings=28,grain=.002)
    plate('Body',-.99,-.44,.23,.12,.13,12,front=True)
    for side in (-1,1):
        sweep('Body',[(side*.17,.065,-.95),(side*.22,.11,-.84),(side*.235,.10,-.72)],
              [.022,.030,.012],'eyes',sides=10,flatten=.5)
        sweep('Body',[(side*.16,.04,-.89),(side*.28,.20,-1.14),(side*.42,.31,-1.37)],
              [.013,.008,.0015],'worn_edge',sides=7)
        sweep('Body',[(side*.27,-.15,-.58),(side*.34,-.27,-.01),(side*.22,-.50,.33)],
              [.037,.048,.018],'skin',sides=10,flatten=.56)
        leg='LandingLeg_L' if side<0 else 'LandingLeg_R'
        sweep(leg,[(side*.17,-.34,.08),(side*.22,-.63,.16),(side*.32,-1.03,.30),(side*.29,-1.42,.45),(side*.30,-1.79,.34)],
              [.043,.049,.044,.027,.018],'skin',sides=10,flatten=.75)
        for digit in (-1,0,1):
            sweep(leg,[(side*.30,-1.76,.34),(side*.30+digit*.055,-1.89,.17),(side*.30+digit*.09,-1.955,.06)],
                  [.015,.013,.001],'worn_edge',sides=7)
        wing='Wing_L' if side<0 else 'Wing_R';rows=55;cols=23;vertices=[];faces=[];depth=[]
        for i in range(rows):
            s=i/(rows-1)
            for j in range(cols):
                t=j/(cols-1);vertices.append(tuple(wing_point(side,s,t)))
                depth.append(.12+.28*math.exp(-t/.052)+.12*math.exp(-(1-t)/.030)+.18*math.exp(-s/.10))
        for i in range(rows-1):
            for j in range(cols-1):a=i*cols+j;faces.append((a,a+cols,a+cols+1,a+1))
        tissue(wing,vertices,faces,depth)
        for s in (.0,.17,.34,.52,.69,.85,1):
            sweep(wing,[wing_point(side,s,t) for t in np.linspace(0,1,7)],
                  [.014*(1-t)+.002 for t in np.linspace(0,1,7)],'worn_edge',sides=7,detail=2)
            if .1<s<.9:
                for t in (.30,.55,.78):
                    sweep(wing,[wing_point(side,s,t),wing_point(side,min(.97,s+.08),t+.075),wing_point(side,min(.985,s+.135),t+.11)],
                          [.0038,.0027,.001],'skin',sides=6,detail=2)
        sweep(wing,[wing_point(side,s,0) for s in np.linspace(0,1,11)],
              [.036*(1-s)+.005 for s in np.linspace(0,1,11)],'skin',sides=10,detail=2)
        sweep(wing,[wing_point(side,s,1) for s in np.linspace(0,1,19)],
              [.004]*19,'skin',sides=6,detail=1)


def material_set(species):
    palette={
        'veyra':{'skin':('263b38','425751',.62),'mineral':('9b9178','d5cab0',.76),'worn_edge':('715437','ac804b',.57),'membrane':('677c73','8ba294',.48)},
        'morrow':{'skin':('3d373d','62565d',.58),'mineral':('a2998e','d0c7b9',.78),'worn_edge':('806b60','ad8d73',.63),'membrane':('81717a','ba9a9c',.45)},
        'aeral':{'skin':('324444','546360',.54),'mineral':('a6ae9f','d2d7c2',.66),'worn_edge':('536d63','96a899',.49),'membrane':('668d89','a9c9bb',.39)},
    }[species]
    result={}
    for role in ('skin','mineral','worn_edge','membrane','eyes','signal'):
        m=bpy.data.materials.new(f'{species}_{role}');m.use_nodes=True;m['role']=role
        nodes=m.node_tree.nodes;nodes.clear();links=m.node_tree.links
        bs=nodes.new('ShaderNodeBsdfPrincipled');bs.name='Export PBR';out=nodes.new('ShaderNodeOutputMaterial');links.new(bs.outputs['BSDF'],out.inputs['Surface'])
        bs.inputs['Metallic'].default_value=0
        if role in ('eyes','signal'):
            color=linear('102b2d' if role=='eyes' else 'b57e3e' if species=='veyra' else 'ae8585')
            bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.19 if role=='eyes' else .48
            if role=='signal':bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=.035
        else:
            low,high,rough=palette[role];bs.inputs['Roughness'].default_value=rough
            geo=nodes.new('ShaderNodeNewGeometry');large=nodes.new('ShaderNodeTexNoise');large.inputs['Scale'].default_value=2.4;large.inputs['Detail'].default_value=2.4
            links.new(geo.outputs['Position'],large.inputs['Vector'])
            ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=(*linear(low),1);ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=(*linear(high),1)
            links.new(large.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
            if role=='membrane':
                attr=nodes.new('ShaderNodeAttribute');attr.attribute_name='TissueThickness'
                shade=nodes.new('ShaderNodeMixRGB');shade.blend_type='MULTIPLY';shade.inputs[0].default_value=.30
                links.new(ramp.outputs['Color'],shade.inputs[1]);links.new(attr.outputs['Color'],shade.inputs[2]);links.new(shade.outputs['Color'],bs.inputs['Base Color'])
            detail=nodes.new('ShaderNodeTexNoise');detail.inputs['Scale'].default_value=46 if role in ('mineral','worn_edge') else 74;detail.inputs['Detail'].default_value=2
            links.new(geo.outputs['Position'],detail.inputs['Vector'])
            bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.0028 if role=='mineral' else .0018 if role=='worn_edge' else .00055 if role=='skin' else .0002
            links.new(detail.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
            rr=nodes.new('ShaderNodeMapRange');rr.inputs['To Min'].default_value=rough-.04;rr.inputs['To Max'].default_value=rough+.045
            links.new(detail.outputs['Fac'],rr.inputs['Value']);links.new(rr.outputs['Result'],bs.inputs['Roughness'])
        result[role]=m
    return result


def merge_opaque_surfaces(meshes):
    common=materials['skin']
    for obj in meshes:
        mapped=[common if m.get('role') in ('skin','mineral','worn_edge') else m for m in obj.data.materials]
        unique=list(dict.fromkeys(mapped));indices=[unique.index(mapped[p.material_index]) for p in obj.data.polygons]
        obj.data.materials.clear()
        for material in unique:obj.data.materials.append(material)
        for polygon,index in zip(obj.data.polygons,indices):polygon.material_index=index


report=[]
requested=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--species=')), 'veyra,morrow,aeral').split(',')
for species,builder in [('veyra',veyra),('morrow',morrow),('aeral',aeral)]:
    if species not in requested:continue
    original=PREVIOUS/f'{species}_runtime.blend';bpy.ops.wm.open_mainfile(filepath=str(original));bpy.context.view_layer.update()
    before={o.name:[list(row) for row in o.matrix_local] for o in bpy.context.scene.objects}
    parts={};materials=material_set(species);builder();meshes=build_meshes(species)
    atlas=bake(species,meshes);merge_opaque_surfaces(meshes)
    assert before=={o.name:[list(row) for row in o.matrix_local] for o in bpy.context.scene.objects}, 'Rig transform changed'
    bpy.ops.file.pack_all();editable=SOURCE/f'{species}_listening.blend';bpy.ops.wm.save_as_mainfile(filepath=str(editable))
    destination=OUT/f'{species}_runtime.glb'
    bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',export_yup=True,export_apply=True,export_animations=False,export_tangents=True,export_cameras=False,export_lights=False)
    repaired=repair_singular_tangents(destination);raw=destination.read_bytes();n=int.from_bytes(raw[12:16],'little');doc=json.loads(raw[20:20+n])
    triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    surfaces=sum(len(m['primitives']) for m in doc['meshes'])
    assert triangles<40000 and len(raw)<8*1024*1024
    row={'species':species,'source':str(original.relative_to(ROOT)),'source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
         'editable':str(editable.relative_to(ROOT)),'file':str(destination.relative_to(ROOT)),'sha256':hashlib.sha256(raw).hexdigest(),
         'bytes':len(raw),'triangles':triangles,'surfaces':surfaces,'materials':len(doc['materials']),'images':len(doc.get('images',[])),
         'rig_and_mesh_node_transforms_unchanged':True,'singular_tangents_repaired':repaired,'atlas':atlas}
    report.append(row);(EVID/f'{species}-build.json').write_text(json.dumps(row,indent=2),encoding='utf-8')
    print('LISTENING_FAUNA_BUILT',json.dumps(row),flush=True)
report=[json.loads((EVID/f'{kind}-build.json').read_text()) for kind in ('veyra','morrow','aeral') if (EVID/f'{kind}-build.json').exists()]
(EVID/'fauna-build.json').write_text(json.dumps({'blender':bpy.app.version_string,'build':bpy.app.build_hash.decode(),
    'provenance':'Original locally authored mineral laminae, skin, tissue and veins over the pre-existing project rigs. No external sources, downloads, paid providers or fonts.',
    'license':'Project-owned original geometry and pigment maps; unrestricted project use.',
    'helper_source':str(helper_source.relative_to(ROOT)),'helper_sha256':hashlib.sha256(helper_source.read_bytes()).hexdigest(),'outputs':report},indent=2),encoding='utf-8')
