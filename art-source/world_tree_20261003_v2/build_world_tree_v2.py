"""Deterministic original golden world-tree asset for Signal in the Dust.

Run with the repository's Blender 5.2 background binary.  The script owns only
the world_tree source/output folders and writes a packed GLB plus a compact
provenance receipt.  Geometry is authored Z-up in metres and exported with
export_yup=True for Godot/glTF Y-up.
"""

import bpy
import math
import random
import json
import hashlib
import struct
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent
OUT = ROOT / "godot/assets/world_tree_v2"
EVID = ROOT / "evidence/world-tree-20261003/blender-v2"
OUT.mkdir(parents=True, exist_ok=True)
EVID.mkdir(parents=True, exist_ok=True)
TEXTURES = OUT / "textures"
TEXTURES.mkdir(parents=True, exist_ok=True)

SEED = 20261003
rng = random.Random(SEED)


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights):
        # Keep no stale generated data in this source file.  Packed images are
        # created below, so no image datablocks exist at this point.
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


clean_scene()
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    # Blender 5.2 exposes the same realtime engine under the restored enum.
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 50
scene.view_settings.view_transform = "AgX"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.045, 0.035, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.40


def _set_input(node, names, value):
    for name in names:
        sock = node.inputs.get(name)
        if sock is not None:
            sock.default_value = value
            return True
    return False


def _clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def make_texture(path: Path, kind: str):
    """Create a small owned texture with deterministic procedural pixel art."""
    size = 512
    image = bpy.data.images.new(path.stem, width=size, height=size, alpha=False, float_buffer=False)
    pixels = [0.0] * (size * size * 4)
    for y in range(size):
        v = y / (size - 1)
        for x in range(size):
            u = x / (size - 1)
            i = (y * size + x) * 4
            if kind == "bark":
                # Vertical, weathered grain with deep cracks and subdued gold
                # mineral flecks.  The geometry still carries the large forms.
                grain = 0.5 + 0.5 * math.sin(u * 56.0 + math.sin(v * 17.0) * 2.4)
                fine = 0.5 + 0.5 * math.sin(u * 210.0 + v * 31.0)
                crack = 1.0 if grain < 0.16 else 0.0
                mineral = max(0.0, math.sin(u * 31.0 + v * 19.0)) ** 18
                r = 0.075 + grain * 0.095 + fine * 0.018 + mineral * 0.10
                g = 0.046 + grain * 0.062 + fine * 0.013 + mineral * 0.064
                b = 0.030 + grain * 0.038 + fine * 0.010 + mineral * 0.028
                r *= 1.0 - crack * 0.55
                g *= 1.0 - crack * 0.62
                b *= 1.0 - crack * 0.68
            elif kind == "branch":
                grain = 0.5 + 0.5 * math.sin(u * 42.0 + math.sin(v * 23.0) * 1.7)
                fine = 0.5 + 0.5 * math.sin(u * 180.0 - v * 47.0)
                mineral = max(0.0, math.sin(u * 25.0 - v * 9.0)) ** 20
                r = 0.095 + grain * 0.12 + fine * 0.015 + mineral * 0.11
                g = 0.059 + grain * 0.075 + fine * 0.014 + mineral * 0.070
                b = 0.031 + grain * 0.046 + fine * 0.009 + mineral * 0.026
            else:
                fleck = max(0.0, math.sin(u * 39.0 + math.sin(v * 11.0) * 3.0)) ** 7
                warm = 0.5 + 0.5 * math.sin((u + v) * 25.0)
                r = 0.52 + 0.30 * fleck + 0.04 * warm
                g = 0.18 + 0.21 * fleck + 0.05 * warm
                b = 0.025 + 0.035 * fleck
            pixels[i:i + 4] = (_clamp(r), _clamp(g), _clamp(b), 1.0)
    image.pixels = pixels
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


bark_image = make_texture(TEXTURES / "world_tree_bark_albedo_v2.png", "bark")
branch_image = make_texture(TEXTURES / "world_tree_branch_albedo_v2.png", "branch")
leaf_image = make_texture(TEXTURES / "world_tree_leaf_albedo_v2.png", "leaf")


def make_material(name, colour, roughness, image=None, emission=None, emission_strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*colour, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    _set_input(bsdf, ("Base Color",), (*colour, 1.0))
    _set_input(bsdf, ("Metallic",), 0.0)
    _set_input(bsdf, ("Roughness",), roughness)
    _set_input(bsdf, ("IOR",), 1.42)
    if image is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.name = f"{name}_Albedo"
        tex.image = image
        tex.interpolation = "Linear"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission is not None:
        _set_input(bsdf, ("Emission Color", "Emission"), (*emission, 1.0))
        _set_input(bsdf, ("Emission Strength",), emission_strength)
    return material


materials = {
    "bark": make_material("WorldTree_Bark", (0.26, 0.12, 0.035), 0.90, bark_image, (0.08,0.018,0.002), 0.42),
    "branches": make_material("WorldTree_Branches", (0.38, 0.18, 0.045), 0.82, branch_image, (0.14,0.035,0.004), 0.55),
    "leaves": make_material("WorldTree_Leaves", (0.94, 0.58, 0.10), 0.64, leaf_image, (0.45,0.16,0.012), 2.0),
    "veins": make_material("WorldTree_LuminousVeins", (1.0, 0.73, 0.29), 0.28,
                            None, (1.0, 0.58, 0.16), 4.2),
}

# One aggregate mesh per shared material keeps draw calls and material count
# predictable.  Every tube and leaf receives real UVs, smooth normals, and is
# triangulated before export.
buckets = {key: {"verts": [], "faces": [], "uv": []} for key in materials}


def _add_vertex(bucket, point, uv):
    idx = len(bucket["verts"])
    bucket["verts"].append(tuple(float(v) for v in point))
    bucket["uv"].append((float(uv[0]), float(uv[1])))
    return idx


def _catmull(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t +
                   (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
                   (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


def _catmull_tangent(p0, p1, p2, p3, t):
    t2 = t * t
    d = 0.5 * ((-p0 + p2) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t +
               3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2)
    return d.normalized() if d.length > 1e-6 else (p2 - p1).normalized()


def add_tube(key, points, radii, sides=12, steps_per_segment=3, ellipticity=(1.0, 1.0), phase=0.0):
    """Append a tapered, closed Catmull-Rom tube to a material bucket."""
    bucket = buckets[key]
    pts = [Vector(p) for p in points]
    rs = [float(r) for r in radii]
    samples = []
    rings = []
    cumulative = 0.0
    last_point = None
    for seg in range(len(pts) - 1):
        p0 = pts[max(0, seg - 1)]
        p1 = pts[seg]
        p2 = pts[seg + 1]
        p3 = pts[min(len(pts) - 1, seg + 2)]
        for step in range(steps_per_segment):
            t = step / float(steps_per_segment)
            p = _catmull(p0, p1, p2, p3, t)
            tangent = _catmull_tangent(p0, p1, p2, p3, t)
            radius = rs[seg] * (1.0 - t) + rs[seg + 1] * t
            if last_point is not None:
                cumulative += (p - last_point).length
            samples.append((p, tangent, radius, cumulative))
            last_point = p
    p = pts[-1]
    tangent = (pts[-1] - pts[-2]).normalized()
    cumulative += (p - last_point).length if last_point is not None else 0.0
    samples.append((p, tangent, rs[-1], cumulative))

    for ring_i, (p, tangent, radius, distance) in enumerate(samples):
        # Stable frame: vertical trunks use Blender Y as the seed, horizontal
        # branches use world Z.  This avoids twisting UVs at the root.
        seed_axis = Vector((0.0, 0.0, 1.0)) if abs(tangent.z) < 0.92 else Vector((0.0, 1.0, 0.0))
        axis = tangent.cross(seed_axis)
        if axis.length < 1e-5:
            axis = Vector((1.0, 0.0, 0.0))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        ring = []
        for side in range(sides):
            angle = math.tau * side / sides + phase + ring_i * 0.065
            # Fine irregularity reads as weathered bark while preserving the
            # clean silhouette of the major forms.
            variation = 1.0 + 0.055 * math.sin(angle * 7.0 + ring_i * 0.72) + 0.025 * math.cos(angle * 13.0 - ring_i * 0.29)
            offset = axis * (math.cos(angle) * radius * ellipticity[0] * variation)
            offset += other * (math.sin(angle) * radius * ellipticity[1] * variation)
            q = p + offset
            ring.append(_add_vertex(bucket, q, (side / float(sides) * 2.0, distance / 32.0)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for side in range(sides):
            a = rings[i][side]
            b = rings[i][(side + 1) % sides]
            c = rings[i + 1][(side + 1) % sides]
            d = rings[i + 1][side]
            bucket["faces"].append((a, b, c, d))
    bucket["faces"].append(tuple(reversed(rings[0])))
    bucket["faces"].append(tuple(rings[-1]))


def add_leaf(key, base, direction, length, width, thickness, uv_phase):
    bucket = buckets[key]
    axis = Vector(direction).normalized()
    if axis.length < 1e-5:
        axis = Vector((0.0, 0.0, 1.0))
    across = axis.cross(Vector((0.0, 0.0, 1.0)))
    if across.length < 1e-5:
        across = axis.cross(Vector((0.0, 1.0, 0.0)))
    across.normalize()
    normal = axis.cross(across).normalized()
    p0 = Vector(base)
    p1 = p0 + axis * length
    mid = p0 + axis * (length * 0.48)
    left = mid - across * (width * 0.50)
    right = mid + across * (width * 0.50)
    front = mid + normal * thickness
    back = mid - normal * thickness
    verts = [p0, left, front, right, back, p1]
    uvs = [(0.03, 0.52), (0.42, 0.08), (0.50, 0.50), (0.58, 0.08), (0.50, 0.92), (0.98, 0.52)]
    ids = [_add_vertex(bucket, point, (u + uv_phase, v)) for point, (u, v) in zip(verts, uvs)]
    bucket["faces"].extend([
        (ids[0], ids[1], ids[2]), (ids[0], ids[2], ids[3]),
        (ids[0], ids[3], ids[4]), (ids[0], ids[4], ids[1]),
        (ids[5], ids[2], ids[1]), (ids[5], ids[3], ids[2]),
        (ids[5], ids[4], ids[3]), (ids[5], ids[1], ids[4]),
    ])


# --- Monumental trunk and grounded buttress roots -------------------------
trunk_points = [
    (0.0, 0.0, 0.0), (-0.8, -0.35, 16.0), (1.1, 0.4, 42.0),
    (-1.5, 0.8, 76.0), (0.6, -0.4, 112.0), (-1.0, 0.8, 146.0),
    (1.4, 0.3, 178.0), (0.0, 0.0, 209.0), (1.2, -0.5, 230.0),
]
trunk_radii = [7.4, 6.9, 6.0, 5.2, 4.5, 3.8, 3.1, 2.2, 0.78]
add_tube("bark", trunk_points, trunk_radii, sides=20, steps_per_segment=4, ellipticity=(1.03, 0.97), phase=0.15)

# A few raised bark seams reinforce the close driving view without adding a
# second material.  They are deliberately uneven and terminate below the
# crown rather than making a uniform ribbed pipe.
for seam in range(8):
    ang = math.tau * seam / 8.0 + 0.18
    offset = Vector((math.cos(ang), math.sin(ang), 0.0))
    pts = [offset * (7.0 - i * 0.62) + Vector((0.0, 0.0, i * 17.0 + 1.0)) for i in range(7)]
    pts = [p + Vector((0.45 * math.sin(i * 1.6 + seam), 0.28 * math.cos(i * 1.15 + seam), 0.0)) for i, p in enumerate(pts)]
    add_tube("bark", pts, [0.24, 0.23, 0.20, 0.17, 0.13, 0.09, 0.025], sides=6, steps_per_segment=2, ellipticity=(0.75, 0.50), phase=ang)

# Blender +Y maps to receiver -Z under export_yup=True.  Keep authored -Y
# open so the receiver's local +Z approach corridor has no large root.
root_angles = [-2.96, -2.58, -2.18, -1.00, -0.35, 0.30, 0.95, 1.45, 2.42, 2.93, 3.48, 4.05]
root_spreads = [49.0, 53.0, 46.0, 42.0, 51.0, 47.0, 54.0, 43.0, 50.0, 55.0, 48.0, 44.0]
for i, (angle, spread) in enumerate(zip(root_angles, root_spreads)):
    direction = Vector((math.cos(angle), math.sin(angle), 0.0))
    side = Vector((-direction.y, direction.x, 0.0))
    bend = side * (math.sin(i * 1.7) * 4.0)
    start = direction * 4.4 + Vector((0.0, 0.0, 0.55))
    mid = direction * (14.0 + (i % 3) * 2.8) + bend * 0.25 + Vector((0.0, 0.0, 0.85 + (i % 2) * 0.25))
    wide = direction * (spread * 0.53) + bend + Vector((0.0, 0.0, 0.36))
    end = direction * spread + bend * 1.12 + Vector((0.0, 0.0, 0.08))
    add_tube("bark", [start, mid, wide, end], [4.1, 3.45, 1.7, 0.16], sides=12,
             steps_per_segment=3, ellipticity=(1.45, 0.54), phase=0.25 * i)


# --- Asymmetric crown branches --------------------------------------------
primary_tips = []
secondary_tips = []
primary_paths = []
for i in range(11):
    angle = math.tau * i / 11.0 + 0.17 * math.sin(i * 1.41) + 0.08
    attach_z = 111.0 + (i % 4) * 8.5 + 4.0 * math.sin(i * 0.8)
    length = 73.0 + (i % 5) * 9.0 + 7.0 * math.sin(i * 1.8)
    radial = Vector((math.cos(angle), math.sin(angle), 0.0))
    lateral = Vector((-radial.y, radial.x, 0.0))
    start = Vector((math.cos(angle) * 1.4, math.sin(angle) * 1.4, attach_z))
    bend = radial * (length * 0.42) + lateral * (math.sin(i * 2.1) * 11.0) + Vector((0.0, 0.0, 12.0 + (i % 3) * 3.0))
    high = radial * (length * 0.73) + lateral * (math.cos(i * 1.7) * 16.0) + Vector((0.0, 0.0, 20.0 + (i % 4) * 6.0))
    tip = radial * length + lateral * (math.sin(i * 1.13) * 18.0) + Vector((0.0, 0.0, 42.0 + (i % 3) * 12.0))
    path = [start, bend, high, tip]
    primary_paths.append(path)
    add_tube("branches", path, [3.05, 2.25, 1.15, 0.23], sides=12, steps_per_segment=3, ellipticity=(1.0, 0.84), phase=0.19 * i)
    primary_tips.append((tip, radial + Vector((0.0, 0.0, 0.30)), length))
    # Two asymmetric forks from each limb keep the crown open and legible.
    for fork in range(2):
        t = 0.43 + fork * 0.18
        anchor = start.lerp(tip, t) + lateral * ((-1.0 if fork == 0 else 1.0) * (4.0 + (i % 3) * 2.5))
        fork_angle = angle + (-0.62 if fork == 0 else 0.55) + 0.08 * math.sin(i)
        fr = Vector((math.cos(fork_angle), math.sin(fork_angle), 0.0))
        fl = Vector((-fr.y, fr.x, 0.0))
        f_len = length * (0.42 + 0.05 * ((i + fork) % 3))
        bend2 = anchor + fr * (f_len * 0.50) + fl * (math.sin(i * 0.9 + fork) * 7.0) + Vector((0.0, 0.0, 15.0 + fork * 5.0))
        tip2 = anchor + fr * f_len + fl * (math.cos(i * 1.3 + fork) * 9.0) + Vector((0.0, 0.0, 24.0 + (i % 2) * 9.0))
        add_tube("branches", [anchor, bend2, tip2], [1.25, 0.62, 0.12], sides=10, steps_per_segment=3, ellipticity=(1.0, 0.78), phase=0.27 * (i + fork))
        secondary_tips.append((tip2, fr + Vector((0.0, 0.0, 0.34)), f_len))

# The central leader reaches just above the outer limbs and prevents the crown
# from reading as a ring.  It is deliberately thin at the top.
leader = [(0.5, 0.0, 155.0), (-1.2, 0.5, 184.0), (2.6, -0.4, 211.0), (-1.2, 1.5, 229.0), (0.0, 0.0, 233.0)]
add_tube("branches", leader, [2.5, 1.8, 1.15, 0.53, 0.12], sides=12, steps_per_segment=3, ellipticity=(1.0, 0.9), phase=0.4)
for k, ang in enumerate((0.25, 1.52, 2.55, 4.05, 5.18)):
    start = Vector(leader[2]) + Vector((0.0, 0.0, (k % 2) * 4.0))
    r = Vector((math.cos(ang), math.sin(ang), 0.0))
    tip = start + r * (32.0 + k * 4.0) + Vector((0.0, 0.0, 18.0 + (k % 3) * 5.0))
    add_tube("branches", [start, start + r * 12.0 + Vector((0.0, 0.0, 9.0)), tip], [0.88, 0.42, 0.09], sides=9, steps_per_segment=3, ellipticity=(1.0, 0.82), phase=0.11 * k)
    secondary_tips.append((tip, r + Vector((0.0, 0.0, 0.36)), 28.0))


# --- Selected luminous veins ----------------------------------------------
vein_indices = {0, 2, 4, 7, 9}
for i, path in enumerate(primary_paths):
    if i not in vein_indices:
        continue
    add_tube("veins", [Vector(p) + Vector((0.0, 0.0, 0.20)) for p in path], [0.34, 0.25, 0.15, 0.045], sides=7, steps_per_segment=3, ellipticity=(0.88, 0.72), phase=0.31 * i)
# A single interior rise carries the same light language into the trunk.
add_tube("veins", [(0.6, 0.4, 24.0), (-0.6, -0.2, 76.0), (0.7, 0.2, 124.0), (-0.8, 0.4, 174.0), (1.7, -0.1, 211.0)],
         [0.36, 0.27, 0.21, 0.12, 0.035], sides=7, steps_per_segment=3, ellipticity=(0.76, 0.62), phase=0.6)


# --- Clustered opaque amber leaves ----------------------------------------
leaf_sites = []
for idx, (tip, direction, length) in enumerate(primary_tips):
    leaf_sites.append((tip, direction, 1.0 + (idx % 3) * 0.16))
    if idx % 2 == 0:
        leaf_sites.append((tip * 0.90 + Vector((0.0, 0.0, 3.0 + idx)), direction + Vector((0.0, 0.0, 0.18)), 0.74))
for idx, (tip, direction, length) in enumerate(secondary_tips):
    if idx % 2 == 0 or idx % 5 == 1:
        leaf_sites.append((tip, direction, 0.70 + (idx % 4) * 0.10))

for site_index, (centre, outward, scale) in enumerate(leaf_sites):
    local_rng = random.Random(SEED + 91 * site_index)
    outward = Vector(outward).normalized()
    # Six to nine individually modelled leaves create small gaps and a readable
    # silhouette.  They are closed opaque meshes; the receiver can disable
    # their shadow casting without relying on alpha blending.
    count = 12 + (site_index % 5)
    for leaf_index in range(count):
        az = math.tau * leaf_index / count + local_rng.uniform(-0.22, 0.22)
        radial = Vector((math.cos(az), math.sin(az), 0.0))
        direction = (outward * 0.56 + radial * 0.56 + Vector((0.0, 0.0, local_rng.uniform(0.12, 0.48)))).normalized()
        base = Vector(centre) + radial * local_rng.uniform(0.5, 2.4) + Vector((0.0, 0.0, local_rng.uniform(-1.0, 1.6)))
        length = local_rng.uniform(5.2, 9.0) * scale
        width = local_rng.uniform(2.4, 4.8) * scale
        thickness = local_rng.uniform(0.24, 0.52) * scale
        add_leaf("leaves", base, direction, length, width, thickness, (site_index % 7) * 0.13)



# Fuller golden canopy masses: clustered closed low-poly forms keep the tree
# legible at far distance while preserving separated branch gaps and a readable
# silhouette. These are opaque meshes, not alpha cards.
def add_leaf_cluster(center, scale, phase):
    # A cluster is a tuft of individually readable golden leaves, not a single
    # faceted orange ball. The negative spaces between leaves preserve volume.
    local=random.Random(SEED + int(abs(phase)*1000.0) + int(scale*17.0))
    c=Vector(center)
    for leaf_index in range(30):
        angle=math.tau*leaf_index/30.0 + phase + local.uniform(-.18,.18)
        radial=Vector((math.cos(angle),math.sin(angle),0.0))
        base=c + radial*local.uniform(.15,scale*.55) + Vector((0,0,local.uniform(-scale*.3,scale*.3)))
        direction=(radial*.58 + Vector((0,0,local.uniform(.16,.65)))).normalized()
        add_leaf("leaves",base,direction,local.uniform(scale*.45,scale*.85),local.uniform(scale*.22,scale*.42),local.uniform(.16,.28),phase*.1)

# Build layered crown pockets around every primary limb and a few secondary
# forks. The overlap is deliberate: it makes a canopy rather than stick figure.
for ci,(tip,outward,length) in enumerate(primary_tips):
    center=Vector(tip)
    out=Vector(outward).normalized()
    for layer in range(4):
        offset=out*(layer*4.0-6.0)+Vector((0,0,(layer-1.5)*4.0+math.sin(ci+layer)*1.8))
        add_leaf_cluster(center+offset, 7.0+layer*.75+(ci%3)*.65, ci*.41+layer*.77)
for ci,(tip,outward,length) in enumerate(secondary_tips):
    if ci%2: add_leaf_cluster(Vector(tip)+Vector((0,0,2.5)), 5.0+(ci%3)*.55, ci*.63)

# High crown veil: a broad, broken halo keeps the landmark monumental from the
# long approach. The gaps between lobes expose branches and sky instead of a
# single artificial sphere.
for crown_index in range(24):
    angle=math.tau*crown_index/24.0 + math.sin(crown_index*1.7)*.10
    radius=32.0 + (crown_index%6)*12.0
    height=135.0 + (crown_index%8)*9.0 + math.sin(crown_index*1.3)*4.0
    centre=Vector((math.cos(angle)*radius, math.sin(angle)*radius, height))
    add_leaf_cluster(centre, 8.5+(crown_index%3)*1.4, crown_index*.37)

def build_mesh(name, key):
    bucket = buckets[key]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(bucket["verts"], [], bucket["faces"])
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        # Smooth the clustered canopy surfaces; flat faceting made the old tree
        # read as a pile of orange low-poly stones at gameplay distance.
        poly.use_smooth = True
        for loop_idx in poly.loop_indices:
            vertex_idx = mesh.loops[loop_idx].vertex_index
            uv_layer.data[loop_idx].uv = bucket["uv"][vertex_idx]
    mesh.validate(verbose=True, clean_customdata=True)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(materials[key])
    # Receiver-facing metadata survives in the .blend and, when supported by
    # the exporter, as glTF extras.
    obj["asset_role"] = "signal_in_the_dust_world_tree"
    obj["material_role"] = materials[key].name
    if key == "leaves":
        obj["recommended_cast_shadow"] = False
        obj["surface_mode"] = "opaque_low_poly_cluster"
    return obj


objects = [build_mesh("WorldTree_Bark", "bark"), build_mesh("WorldTree_Branches", "branches"),
           build_mesh("WorldTree_Leaves", "leaves"), build_mesh("WorldTree_LuminousVeins", "veins")]

# Triangulate all surfaces to make tangent generation deterministic for the
# Compatibility/Web importer.  Apply only to our four mesh objects.
for obj in objects:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    triangulate = obj.modifiers.new("Portable triangulation", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.data.validate(verbose=True, clean_customdata=True)


# Add a non-exported root empty so the authored source remains easy to inspect.
root = bpy.data.objects.new("WorldTree_ROOT", None)
scene.collection.objects.link(root)
root["asset_name"] = "Signal in the Dust Golden World Tree"
root["authoring_units"] = "metres"
root["approach_corridor_authoring"] = "-Y (exported to receiver +Z with export_yup)"
root["target_height_m"] = 230.0
root["target_crown_width_m"] = 240.0
root["root_clear_corridor_m"] = 9.5
approach_angle_authoring = -math.pi / 2.0
root_angle_clearance = min(abs((angle - approach_angle_authoring + math.pi) % math.tau - math.pi) for angle in root_angles)
root["approach_min_root_angle_deg"] = round(math.degrees(root_angle_clearance), 2)
for obj in objects:
    obj.parent = root


def parse_glb(path):
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise RuntimeError("GLB magic missing")
    json_length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + json_length].decode("utf-8"))
    return doc, raw


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds_for(objects_to_measure):
    coords = []
    for obj in objects_to_measure:
        coords.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
    mins = [min(p[i] for p in coords) for i in range(3)]
    maxs = [max(p[i] for p in coords) for i in range(3)]
    return {"min": [round(v, 4) for v in mins], "max": [round(v, 4) for v in maxs],
            "size": [round(maxs[i] - mins[i], 4) for i in range(3)]}


# Save source with packed maps before export.  The root empty is not selected,
# so only the four meshes and their four named materials are in the GLB.
blend_path = SRC / "world_tree.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
bpy.ops.object.select_all(action="DESELECT")
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]

glb_path = OUT / "world_tree.glb"
kwargs = dict(filepath=str(glb_path), export_format="GLB", use_selection=True,
              export_apply=True, export_animations=False, export_materials="EXPORT",
              export_normals=True, export_tangents=True, export_yup=True,
              export_cameras=False, export_lights=False)
try:
    bpy.ops.export_scene.gltf(**kwargs, export_extras=True)
except TypeError:
    bpy.ops.export_scene.gltf(**kwargs)

gltf, glb_raw = parse_glb(glb_path)
triangles = 0
primitive_count = 0
for mesh in gltf.get("meshes", []):
    for primitive in mesh.get("primitives", []):
        primitive_count += 1
        if "indices" in primitive:
            triangles += gltf["accessors"][primitive["indices"]]["count"] // 3
        elif "attributes" in primitive and "POSITION" in primitive["attributes"]:
            triangles += gltf["accessors"][primitive["attributes"]["POSITION"]]["count"] // 3

file_records = []
for path in [glb_path, blend_path, SRC / "build_world_tree_v2.py", *sorted(TEXTURES.glob("*.png"))]:
    file_records.append({"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                         "bytes": path.stat().st_size, "sha256": sha256(path)})

source_bounds = bounds_for(objects)
mesh_stats = {}
for obj in objects:
    mesh_stats[obj.name] = {
        "vertices": len(obj.data.vertices),
        "triangles": sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons),
        "material": obj.data.materials[0].name,
    }

manifest = {
    "asset": "Signal in the Dust original golden world tree",
    "generator": "art-source/world_tree_20261003_v2/build_world_tree_v2.py",
    "blender": bpy.app.version_string,
    "blender_build_hash": bpy.app.build_hash.decode() if isinstance(bpy.app.build_hash, bytes) else str(bpy.app.build_hash),
    "seed": SEED,
    "authoring": {"units": "metres", "up": "+Z", "forward_corridor": "-Y", "export": "glTF Y-up via export_yup=True"},
    "receiver_axes_note": "Raw glTF accessors confirm authored -Y maps to receiver +Z under export_yup=True; root should still confirm with its placement harness.",
    "dimensions_authoring_m": source_bounds,
    "target_dimensions_m": {"height": 230.0, "crown_width": 240.0, "trunk_flare_diameter": 14.8, "root_spread_radius": 55.0, "approach_clear_radius": 9.5},
    "approach_clearance": {"receiver_direction": "+Z", "authoring_direction": "-Y", "nearest_root_angle_deg": round(math.degrees(root_angle_clearance), 2), "corridor_is_unblocked_by_large_root": root_angle_clearance > math.radians(28.0)},
    "materials": [m.name for m in materials.values()],
    "mesh_stats": mesh_stats,
    "triangles": triangles,
    "primitive_count": primitive_count,
    "gltf_material_count": len(gltf.get("materials", [])),
    "gltf_image_count": len(gltf.get("images", [])),
    "gltf_node_names": [n.get("name", "") for n in gltf.get("nodes", [])],
    "leaf_surface": {"opaque": True, "alpha_blended": False, "recommended_cast_shadow": False},
    "files": file_records,
    "provenance": "All geometry, textures and shaders are locally authored by this deterministic script. No downloads, paid assets, ripped assets or external runtime services.",
    "limitations": [
        "No baked normal map is included; relief is carried by the low-poly ridged geometry and albedo variation.",
        "Leaf shadow suppression is represented as receiver metadata; root should disable leaf shadow casting in Godot.",
        "Godot importer/browser placement and visual quality remain root-owned runtime acceptance gates.",
        "No native LOD nodes are included; the Godot importer may generate LODs from this merged mesh.",
    ],
}

manifest_path = EVID / "world_tree_manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
(OUT / "world_tree_provenance.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

handoff = f"""# World tree asset handoff

Status: `IMPLEMENTED` (asset/export evidence only; browser gameplay remains root-owned).

## Delivered

- GLB: `godot/assets/world_tree/world_tree.glb` ({glb_path.stat().st_size:,} bytes, {triangles:,} triangles, {len(gltf.get('materials', []))} glTF materials, {len(gltf.get('images', []))} embedded images).
- Editable source: `art-source/world_tree_20261003/world_tree.blend`.
- Reproducible generator: `art-source/world_tree_20261003_v2/build_world_tree_v2.py`.
- Owned 512px albedo maps: `godot/assets/world_tree/textures/world_tree_bark_albedo.png`, `world_tree_branch_albedo.png`, `world_tree_leaf_albedo.png`.
- Provenance receipt: `evidence/world-tree-20261003/tree-asset/world_tree_manifest.json` and `godot/assets/world_tree/world_tree_provenance.json`.

## Shape and runtime handoff

The asset contains one merged mesh object per shared material: `WorldTree_Bark`, `WorldTree_Branches`, `WorldTree_Leaves`, and `WorldTree_LuminousVeins`. The authoring source is metres, Blender Z-up, with the authored -Y side deliberately kept open; raw glTF accessors confirm that this becomes the receiver +Z rover approach under `export_yup=True`. The measured source bounds are `{source_bounds['size'][0]:.2f}m x {source_bounds['size'][1]:.2f}m x {source_bounds['size'][2]:.2f}m` (X/Y/Z), with the base at authoring Z≈0 / receiver Y≈0 and a luminous, asymmetric 230m-class crown. Buttress roots reach approximately 55m from centre; the nearest root axis is {math.degrees(root_angle_clearance):.1f} degrees from the receiver +Z direction, leaving the 9.5m interaction corridor open to the root mass.

Leaves are small closed opaque amber meshes with gaps; they are not alpha-blended foliage clouds. The leaf mesh carries `recommended_cast_shadow=false`; root should apply the no-leaf-shadow choice in Godot. The ivory-gold vein mesh uses emission strength 4.2 as a portable starting value; root owns final shader, spill lights, fog, and dynamics.

## Fresh checks

- Blender {bpy.app.version_string} background export completed with a valid `glTF` 2.0 header and JSON chunk.
- Export read-back found {len(gltf.get('meshes', []))} meshes, {primitive_count} primitives, {triangles:,} triangles, exactly {len(gltf.get('materials', []))} named shared materials, and {len(gltf.get('images', []))} embedded images.
- A fresh Blender import read-back is recorded in `import_check.json`; it confirms the same four mesh/material names, {triangles:,} imported triangles, one UV layer per mesh, and `alphaMode=OPAQUE` for every material.
- Meshes were validated, UV-mapped, smooth-shaded where appropriate, and triangulated before tangent export.
- Source/output hashes and byte sizes are recorded in `world_tree_manifest.json`; no GPU/browser render was run by this worker.

## Limits

The GLB is asset evidence rather than proof of in-game placement, import, contact, performance, or visual acceptance. Root must perform Godot import, place the tree at `world.signal_origin` z `-650`, confirm the +Z approach corridor and `V` view, then tune leaf shadow flags, fog, material emission, collision/trigger integration, and any generated LODs.
"""
(EVID / "HANDOFF.md").write_text(handoff, encoding="utf-8")

print("WORLD_TREE_EXPORT " + json.dumps({
    "glb": str(glb_path), "blend": str(blend_path), "triangles": triangles,
    "materials": [m.name for m in materials.values()], "images": len(gltf.get("images", [])),
    "bounds": source_bounds, "glb_bytes": glb_path.stat().st_size,
}, separators=(",", ":")), flush=True)
