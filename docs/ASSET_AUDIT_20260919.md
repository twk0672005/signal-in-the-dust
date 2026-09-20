# Existing asset audit — 2026-09-19

| Content | Current evidence | Decision |
|---|---|---|
| rover.glb, signal.glb, rocks.glb/rocks_low.glb | Original local Blender generator and editable source; art-source/README.md and evidence/assets/report.json | Reuse/edit existing authored geometry; preserve source/hash history. Studio renders are not game-quality proof. |
| Original terrain maps and six audio WAVs | Local generators and provenance records | Reuse. Preserve map channel conventions and verify costs after visual changes. |
| Signal Sans TC subset | Official Noto Sans TC OFL1.1 source hash checked; source retained;298 characters in current runtime scripts covered | Reuse; regenerate subset when new text appears, retain OFL and derivative-family name. |
| Terrain3D addon | MIT at research/terrain3d-1.0.2/addons/terrain_3d/LICENSE.txt; ZIP hash A071850250EC5E596AA54DA61C01D75768774EB379EE997584D426A45F4884A2 rechecked | Isolated authoring candidate. Native/Web integration not proven. |
| Terrain3D demo textures | demo/assets/textures/asset_licenses.txt explicitly lists ambientCG CC0 Ground037,Rock030,Rock023 | Eligible to derive alien ice/mineral/wetland materials while keeping original map/source records. Present package has Ground037 andRock023 PNG albedo+height/normal+roughness pairs. Packed alpha channels must be used correctly. |
| Terrain3D demo RockA/B/C and Tunnel GLBs | Models present; addon MIT is confirmed, but no dedicated model-specific attribution was found in this bounded pass | Keep as reference until upstream demo provenance is resolved; do not assign the texture CC0 license to unrelated meshes. |

Correction: the earlier `--path .../demo --editor --quit-after5` exit0 log does NOT establish addon loading. This downloaded tree has no standalone project.godot. A valid future probe must create an isolated project, import the extension, assert ClassDB Terrain3D registration and instantiate/render/export it. No change to frozen downloads or active runtime is implied by this audit.

Performance: bounds and triangle counts are budgets, not quality verdicts. Verify real first/third-person captures, on-device frame-time tails, and Web once each adapted material family is integrated.
