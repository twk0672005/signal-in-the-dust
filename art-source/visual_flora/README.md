# Authored alien flora kit

This directory owns original deterministic Blender sources for six distinct flora families. It does not own terrain, placement, collisions, Godot import settings, wind shaders, runtime lights, gameplay or build/export.

Reference authority: `docs/visual-upgrade-art/EXECUTION_ART_SPEC.md` and `WORLD_ECOLOGY_CONCEPT.md` in the active source; specifically the six-family flora plate and ecosystem-scale image. The concept images are visual references and are not embedded in these models or textures.

The authoring target is static sculptural geometry with physically separate hard bark, ribs, tissue, wax skin, inner gills and localized light organs. Neutral renders disable all emission. Night renders use blue-violet/cyan/amber area lighting. All inspection renders reimport the actual exported GLB; they do not render the original modelling scene.

## Tool and exact rerun commands

Working directory: `C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923`

Verified executable: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`

Verified version: Blender 5.2.1 LTS, build `9e2066aef7ef`, 2026-08-25. No installation, network dependency, downloaded model, external texture photograph, third-party Blender addon or paid provider is used.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art-source/visual_flora/build_flora.py -- --families canopy,sails,pods,cups,mat,spores
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art-source/visual_flora/build_lods.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art-source/visual_flora/render_flora.py -- --families canopy,sails,pods,cups,mat,spores --views front,side,back,night
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art-source/visual_flora/readback_blends.py
python art-source/visual_flora/audit_glbs.py
python art-source/visual_flora/contact_sheet.py --views front,night --name neutral-night-contact
python art-source/visual_flora/contact_sheet.py --views front,side,back --name neutral-multiview-contact
```

`build_flora.py` seeds each family separately, writes original 512 px PBR maps and packed native `.blend` files, then exports GLB with UVs, normals, materials and metre-scale transforms. `build_lods.py` derives static distant forms and merges by material. NumPy is bundled in Blender; the evidence assembler uses the already installed system Python/Pillow. The binary auditor uses installed system NumPy 2.4.6.

## Handoff conventions

- Exported format is glTF 2.0 binary with embedded PNG maps. Base color and emission are sRGB; roughness and tangent-space OpenGL normals are non-color. Normal orientation is the standard Blender/glTF convention. No non-exportable procedural shader node is required.
- One world unit is one metre. Blender Z up is converted by the glTF exporter to Godot Y up. Every family root is placed at the terrain-contact origin, `(0,0,0)`. Negative root geometry is intentionally subsoil. Do not offset the family upward to its minimum bound; that suspends smaller surface parts above terrain.
- Authored forward inspection faces generally Blender -Y, which exports to Godot +Z. Families may be rotated freely around up. All object scales are identity. Component pivots for sails and individual pods sit near their own bases; they are candidates for secondary wind motion. No animation clips or rig are claimed.
- Most materials are opaque. `sail_tissue` uses alpha 0.94 and double-sided glTF BLEND on a real thickness shell. This is a modest translucency cue, not glass or a full transmission model. Test its sorting/overdraw in Compatibility. Canopy, cups and pods are opaque surfaces with material/geometry thickness; local ripe-pod emission has its own baked map.
- Cup interior and exterior are two material sides of the same physical shell. Open pods expose inner valves and seeds. Spore crust includes real perforations, pale hanging gill surfaces and a decaying host root. The ground mat has open gaps and no rectangular support plane.
- Fine layered mineral bark overlays are intentionally open-backed surfaces. Primary supports, shells and roots carry volume. Do not generate collision from every render triangle. Canopy clearance, actor perch, terrain placement and collision proxies must be verified by the runtime owner.
- High files preserve individual components. `_lod1.glb` files reduce triangles to approximately 24% and consolidate by material. They are static distant forms; do not assume high-form per-sail wind pivots survive consolidation. They need a real camera-distance and silhouette transition check.
- Embedded textures occur in both high and distant files for portable handoff. Verify engine texture deduplication or share imported materials before preloading both tiers on mobile. Triangle reductions alone do not establish a frame-rate or memory budget.

## Validation and limits

Reports live under `evidence/visual-upgrade-20260923/flora-authoring/`. The binary audit checks every primitive's positions, indices, normals, UVs, texture storage and material properties. Source readback reopens each `.blend` and checks geometry, UVs, transforms and units. Render JSON identifies the exact GLB hash, camera, viewport and whether emission was enabled.

The intended completion boundary is an inspectable local asset kit. No Godot import/export/build was run by this helper. No Web performance, target-game lighting, terrain contact on actual heightfields, transparency sorting in Compatibility, complete ecology, 90% concept similarity or final acceptance is claimed.

Original local procedural geometry and raster PBR texture authoring; no third-party asset license obligations are introduced. Concept reference provenance remains owned by the parent project. Static art candidate awaiting independent review and runtime integration.
