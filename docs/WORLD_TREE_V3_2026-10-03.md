# World tree v3 reference-locked rebuild

Nova identified that v1/v2 were the wrong species. The supplied image is a pale ivory monumental tree with a massive central trunk, dense upward and lateral fine branches, a broad luminous crown and small warm-gold leaf points in green-gold atmospheric light. v3 follows that source contract through the `reference-to-3d` and `reference-analysis-validator` workflows.

The Blender 5.2.1 source is `art-source/world_tree_20261003_v3/world_tree.blend`; the deterministic builder is `build_world_tree_v3.py`; the runtime GLB is `godot/assets/world_tree_v3/world_tree.glb`. Import QA is PASS at 58,024 triangles, four opaque materials and one UV layer per mesh. Blender far/mid/near renders and the reference manifest are under `evidence/world-tree-20261003/blender-v3/`.

Godot `contact.gd` now loads v3. The actual Web candidate passed entry QA, reached first playable in 18.106 seconds, drove through all four regions, reached the endpoint and completed the 24-second response after real E interaction with zero page errors. The candidate remains local on `codex/world-tree-v2-20261003`; v3 is not published. Close-range taste acceptance remains open because a single supplied perspective image cannot fully prove every hidden side of the 3D reconstruction.
