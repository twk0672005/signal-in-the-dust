# Signal in the Dust — authored asset source

## Contract

Three original, locally authored assets establish a grounded scientific expedition:
an ivory six-wheel field rover, a mineral signal whose ribs answer the player,
and a family of five weathered basalt shapes. Five-second read: recognizable
scientific vehicle, organic mineral antenna, directional eroded geology.

Static source studies only: no baked animation, video or game-quality claim.
The Godot controller owns wheel spin and the signal unfolding interaction.
Contact-sheet views: rover front and rear, full signal silhouette, rock family.
Cycles studio lighting is evidence lighting and is not shipped in GLB.

## Build and inspect

Validated executable: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`
(Blender 5.2.1 LTS, build `9e2066aef7ef`). No add-ons, downloaded assets, external
services, or third-party Python packages are required for geometry authoring.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python ./art-source/build_assets.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python ./art-source/verify_assets.py
python ./art-source/contact_sheet.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python ./art-source/build_rock_lod.py
```

`signal-in-the-dust.blend` is the editable source, with one collection per asset.
Only the rover is visible by default; unhide the SIGNAL / ROCKS collections to
inspect them. All export assets retain their origin around world ground centre.
The build uses a deterministic seed (`15092026`). Pixel-identical render hashes
across differing render devices are not claimed.

## Godot integration

- `godot/assets/models/rover.glb`: `rover_body` and six independent `wheel_*`
  nodes. Forward is Godot **-Z**, up is **+Y**. Wheel axles are local **X**;
  accumulate local X rotation according to signed travel / wheel radius (0.355m).
  Left/right names describe the rover's own sides; `01` is rear, `03` is front.
- `signal.glb`: `rib_01` through `rib_08`, each pivot planted on the ground,
  plus `signal_roots`. Save initial transforms before animating. Tilt each rib
  outward along its radial direction, rather than rotating every rib on one
  common world axis. Restore initial transforms on restart.
- `rocks.glb`: independent `rock_01` through `rock_05`, footprints normalized
  to around 1m. The GLB intentionally contains overlapping rock variants at the
  origin; extract/instance individual meshes, **not the entire scene**, for
  terrain dressing. Each mesh bottom is at ground height.
- `rocks_low.glb`: same five named meshes, approximately 320 triangles each,
  derived by `build_rock_lod.py`. Use this for the bulk of mid/far landscape
  instances and reserve high meshes (1,280 triangles each) for hero foreground.
  Both variants preserve a single material surface per rock, vertex colours
  and the embedded normal texture. Low source derives from the editable high
  geometry in the main blend; the low variant is not a separate hand-edited source.
- Materials use standard glTF base colour, vertex colours, metallic, roughness,
  tangent normals and restrained emission. No Blender-only runtime noise shaders.
  Paint chips, bolts, radiator fins and chevron tyres are geometry. Mineral strata
  use vertex colours and a shared locally synthesized 256px normal map embedded
  into each relevant GLB; there is no external runtime texture dependency.
- Bounds, exact triangle totals, material/primitive counts and SHA-256 hashes
  are recorded in `evidence/assets/report.json`. Combined limits: 100k triangles
  and 12MB GLB + texture payload. Runtime instancing/LOD remains integration work.

## Provenance and licence

All asset geometry and material choices were authored locally for this project
by the supplied script. No downloaded meshes, scans, images, texture libraries,
or paid generation were used. Original geometry is project-owned and can be
modified or distributed with the game. The small mission marks use Blender's
bundled Bfont converted to mesh. Contact-sheet labels use the local Windows
Segoe UI font only in the evidence image; it is not distributed as a font file.
The basalt normal map is original local `mathutils.noise` synthesis; its editable
recipe is in the script and its PNG is under `godot/assets/textures/`.

Godot 4.7.2 has a confirmed GLTF vertex-colour import regression. The basalt
material is intentionally named `basalt vertex strata-vcol`; Godot's documented
`-vcol` suffix enables `vertex_color_use_as_albedo` during import. Native proof
under `evidence/assets/godot-material-fix/` verifies this flag and the corrected
dark result without runtime material overrides.

## Evidence boundary

Source/export/read-back and contact-sheet review prove the authored assets only.
Godot import, gameplay readability, actual web performance and market approval
belong to the integrating root. The assets remain candidates until those pass.
