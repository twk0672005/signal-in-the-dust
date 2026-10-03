# GitHub skill gap audit — world tree v3

Date: 2026-10-03  
Scope: identify a missing capability behind the rejected world-tree close-up, using public GitHub sources and the actual project evidence.

## Finding

There is no missing generic Blender or reference skill in the local catalog. The project already has `reference-to-3d`, `reference-analysis-validator`, `reference-look-calibration`, `multiview-fit-loop`, `realtime-environment-art`, `blender-materials`, `blender-lighting`, and `blender-export`. The failure was execution: v3 skipped the texture assignment and look-calibration gates, then replaced every imported GLB material at runtime with a flat `StandardMaterial3D` override. The format/import checks therefore passed while the close-up read as a flat, overbright wall.

## Public candidates reviewed

- [viettranx/3dviz-pro-max](https://github.com/viettranx/3dviz-pro-max) — MIT, 639 stars at review time. Its `3dviz-pro-max` skill explicitly requires intent, silhouette/proportion reasoning, overview/inspection/close-up targets, real browser inspection, and subject-specific refinement. This is useful process guidance, but it overlaps the installed local skills and does not add a runtime asset pipeline.
- [scenario-labs/skills](https://github.com/scenario-labs/skills) — MIT, 850 stars at review time. The repository includes `scenario-3d-worlds`, `scenario-game-assets`, `scenario-consistency`, and `scenario-quality-gate`, but those routes depend on the Scenario service and can incur account/provider cost. They are not needed for this offline Godot/Blender repair.
- [friggog/tree-gen](https://github.com/friggog/tree-gen) — 954 stars at review time, GPL-3.0. It is a useful reference for natural branching variation, but its license and generic procedural silhouette make it unsuitable for direct inclusion in this project without a separate asset/legal decision. Its method can inspire a local recipe only.
- [ProfRino/Blender-MCP-Assembly-Skill](https://github.com/ProfRino/Blender-MCP-Assembly-Skill) — 74 stars at review time. Its connection planning and overlap/bounds audits directly address detached or intersecting branch joints; the project can absorb those checks without installing a duplicate top-level skill.
- [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender) — 29,916 stars at review time. The existing Blender MCP bridge is already connected and passed a scene read-back, so replacing the bridge would not address the visual defect.
- [DLR-RM/BlenderProc](https://github.com/DLR-RM/BlenderProc) — 3,731 stars at review time. Strong for offline multi-camera render/segmentation QA, but not required to author the runtime GLB and would add a separate pipeline.
- [cth9191/blender-to-web](https://github.com/cth9191/blender-to-web) — 81 stars at review time. Its handoff guidance is for Three.js website sculptures, while this product is an existing Godot Web game; it is not the correct engine route.

## Decision

Do not install a duplicate or provider-dependent skill. Use the public methods as a bounded gap repair: preserve imported PBR textures, add connection/overlap and near/mid/far composition gates, and re-run the actual Godot browser journey. The repaired artifact remains the source of truth; GitHub popularity alone is not a visual acceptance signal.

