# Microfauna candidate contract

Inherited parent: Signal in the Dust visual upgrade, PM /root. This is a bounded offline authoring stage; no game or MARKET acceptance is claimed.

Exactly two provisional technical species IDs: `detritus_crawler_01` and `membrane_flier_01`. The crawler has a continuous 0.35 m trunk, layered seed-shaped mineral dorsal plates, six articulated legs, tactile feelers and no detached parts. The flier has a 0.22 m segmented body, 0.65 m maximum rest wing span, two distinct pairs of curved ribbed insect membranes and short hooked legs. It is not the Aeral anatomy scaled down.

Visual grammar: indigo/slate violet chitin with weathered growth streaks; plum moist joints; restrained cyan/amber sensory seams; muted dusty teal and lilac membrane. The anatomy owns the silhouette. No glowing dots, particles, floating spheres or straight-rod anatomy substitutions.

Source reference: active-root `docs/visual-upgrade-art/WORLD_ECOLOGY_CONCEPT.md`, `EXECUTION_ART_SPEC.md`, `ecosystem-scale-v1.png`, `flora-habitat-v1.png`. References are read only, and no pixels or meshes are copied. Geometry, texture formulas and clips are authored locally from a deterministic script. No provider, downloaded model or external asset library.

Target: Godot 4.7.2 Compatibility/Web via GLB. This worker may not import or run Godot. Blender Z up, +Y forward, meters; exporter converts to glTF Y up, -Z forward. Origin remains fixed at ground projection/body center for the crawler and thorax for the flier. No world travel is baked into animation.

Clips: crawler `idle` (48 frames, 24 fps, two seconds) and `walk` (24 frames, 24 fps, one second, in place tripod cycle). Flier `flutter` (24 frames, 24 fps, one second); articulated root flutter plus distal membrane lag. Rest pose is a neutral spread pose, not an animated perch state.

One shared 512 px atlas family: base color, tangent normal, packed ORM. One opaque material surface for crawler; two surfaces for flier (body and intentionally translucent double-sided membranes). Raw shared texture source is stored once under the source directory; GLBs embed maps for portable handoff. Geometry/bytes/surface counts are measured after export; no arbitrary polygon number substitutes for appearance.

Evidence: original .blend and reproducible Python, version/process identity, GLB parsing, clean fresh-process reimport, neutral close three-quarter and side/contact views per asset, two separated animation samples and numeric deformation samples, file hashes. One internal visual repair maximum, then return to PM/independent review with residuals. In-engine dimensions, habitat visibility, animation blending/contact, Web transparency and performance remain integration gates.

Write ownership is restricted to `art-source/visual_microfauna`, `godot/assets/visual_microfauna`, `evidence/visual-upgrade-20260923/microfauna-authoring` in the named visual-upgrade worktree. No shared MCP, Godot, world/UI/source or other creature changes.
