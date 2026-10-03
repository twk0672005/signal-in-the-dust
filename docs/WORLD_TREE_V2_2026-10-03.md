# World tree v2 — Blender reconstruction

Nova rejected the first tree in actual browser review because it read as sparse orange/black limbs. The candidate was preserved under `godot/assets/world_tree/` and its captures remain in `evidence/world-tree-20261003/`.

The replacement is authored in Blender 5.2.1 with the installed cc-blender modeling/material/lighting/export/QA guidance. It uses a curved flared trunk, buttress roots with an open approach corridor, many asymmetric branch tubes, smooth clustered gold leaf tufts, selected luminous veins and a high crown veil. Blender beauty renders are `evidence/world-tree-20261003/blender-v2/{far,mid,near}.png`; imported GLB QA is PASS at 35,960 triangles, four materials, one UV layer per mesh and opaque leaves.

The actual Godot Web candidate uses `res://assets/world_tree_v2/world_tree.glb`. Root darkened the sky/ambient/fog relationship and added grounded dark arrival ruins around the endpoint while preserving the existing 24-second contact signal, save state, four-region controls, creatures, bilingual UI and touch flow.

Browser evidence: entry-v2-final is PASS; v2 startup reached first playable in 17.306 seconds; the real-control route discovered all four regions and reached the endpoint; the endpoint interaction was accepted and completed to `phase=ending` after the 24-second sequence, with no page errors. The candidate is still `PARTIAL` for product taste because Nova has not accepted the v2 close-up/far composition and the second art update is not published.
