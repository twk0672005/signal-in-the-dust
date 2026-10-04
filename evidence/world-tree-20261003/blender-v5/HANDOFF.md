# World tree asset handoff

Status: `IMPLEMENTED` (asset/export evidence only; browser gameplay remains root-owned).

## Delivered

- GLB: `godot/assets/world_tree/world_tree.glb` (7,037,396 bytes, 83,848 triangles, 4 glTF materials, 3 embedded images).
- Editable source: `art-source/world_tree_20261003/world_tree.blend`.
- Reproducible generator: `art-source/world_tree_20261004_v5/build_world_tree_v5.py`.
- Owned 512px albedo maps: `godot/assets/world_tree/textures/world_tree_bark_albedo.png`, `world_tree_branch_albedo.png`, `world_tree_leaf_albedo.png`.
- Provenance receipt: `evidence/world-tree-20261003/tree-asset/world_tree_manifest.json` and `godot/assets/world_tree/world_tree_provenance.json`.

## Shape and runtime handoff

The asset contains one merged mesh object per shared material: `WorldTree_Bark`, `WorldTree_Branches`, `WorldTree_Leaves`, and `WorldTree_LuminousVeins`. The authoring source is metres, Blender Z-up, with the authored -Y side deliberately kept open; raw glTF accessors confirm that this becomes the receiver +Z rover approach under `export_yup=True`. The measured source bounds are `278.66m x 259.96m x 254.04m` (X/Y/Z), with the base at authoring Z≈0 / receiver Y≈0 and a luminous, asymmetric 230m-class crown. Buttress roots reach approximately 55m from centre; the nearest root axis is 32.7 degrees from the receiver +Z direction, leaving the 9.5m interaction corridor open to the root mass.

Leaves are small closed opaque amber meshes with gaps; they are not alpha-blended foliage clouds. The leaf mesh carries `recommended_cast_shadow=false`; root should apply the no-leaf-shadow choice in Godot. The ivory-gold vein mesh uses emission strength 4.2 as a portable starting value; root owns final shader, spill lights, fog, and dynamics.

## Fresh checks

- Blender 5.2.1 LTS background export completed with a valid `glTF` 2.0 header and JSON chunk.
- Export read-back found 4 meshes, 4 primitives, 83,848 triangles, exactly 4 named shared materials, and 3 embedded images.
- A fresh Blender import read-back is recorded in `import_check.json`; it confirms the same four mesh/material names, 83,848 imported triangles, one UV layer per mesh, and `alphaMode=OPAQUE` for every material.
- Meshes were validated, UV-mapped, smooth-shaded where appropriate, and triangulated before tangent export.
- Source/output hashes and byte sizes are recorded in `world_tree_manifest.json`; no GPU/browser render was run by this worker.

## Limits

The GLB is asset evidence rather than proof of in-game placement, import, contact, performance, or visual acceptance. Root must perform Godot import, place the tree at `world.signal_origin` z `-650`, confirm the +Z approach corridor and `V` view, then tune leaf shadow flags, fog, material emission, collision/trigger integration, and any generated LODs.
