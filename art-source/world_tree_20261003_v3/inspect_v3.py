"""Import/read-back proof for the authored world tree (no render)."""
import bpy
import json
import struct
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "godot/assets/world_tree_v3/world_tree.glb"
EVID = ROOT / "evidence/world-tree-20261003/blender-v3"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(GLB))
objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]

coords = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
bounds = {
    "min": [round(min(p[i] for p in coords), 4) for i in range(3)],
    "max": [round(max(p[i] for p in coords), 4) for i in range(3)],
}
bounds["size"] = [round(bounds["max"][i] - bounds["min"][i], 4) for i in range(3)]
triangles = sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons) for o in objects)
materials = sorted({m.name for o in objects for m in o.data.materials if m})
uv_layers = {o.name: len(o.data.uv_layers) for o in objects}

raw = GLB.read_bytes()
json_length = struct.unpack_from("<I", raw, 12)[0]
doc = json.loads(raw[20:20 + json_length].decode("utf-8"))
primitive_count = sum(len(mesh.get("primitives", [])) for mesh in doc.get("meshes", []))
alpha_modes = sorted({m.get("alphaMode", "OPAQUE") for m in doc.get("materials", [])})
receipt = {
    "status": "PASS" if len(objects) == 4 and triangles <= 70000 and len(materials) == 4 and len(alpha_modes) == 1 and alpha_modes[0] == "OPAQUE" else "FAIL",
    "glb": str(GLB.relative_to(ROOT)).replace("\\", "/"),
    "sha256": hashlib.sha256(raw).hexdigest(),
    "bytes": len(raw),
    "imported_mesh_objects": [o.name for o in objects],
    "triangles_imported": triangles,
    "primitive_count": primitive_count,
    "materials_imported": materials,
    "uv_layers": uv_layers,
    "alpha_modes": alpha_modes,
    "embedded_images": len(doc.get("images", [])),
    "bounds_after_import": bounds,
    "render_performed": False,
    "gpu_used": False,
}
(EVID / "import_check.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print("WORLD_TREE_IMPORT_CHECK " + json.dumps(receipt, separators=(",", ":")), flush=True)


