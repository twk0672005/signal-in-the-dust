# First-person view and export cleanup

The sensor mount is raised from 1.40m to 1.52m. Its fore-aft position, pitch and FOV are retained. The rover controller, physics and third-person rig were not altered.

## Evidence
At matched terrain-settled poses at1440x900, real rover-only white render masks gave:
- Spawn:25.232% of viewport before,11.650% after.
- Ridge:22.118% before,9.860% after.
- Rift:23.311% before,11.531% after.

These are staged composition measurements, not full-route occlusion guarantees. A small peripheral housing edge remains in some poses. The more elevated/forward candidates were rejected because they removed the bonnet entirely. A per-part sensor layer experiment was removed after verifying the existing rover GLB has a combined body mesh.

Raw before/after images and masks: evidence/camera-composition-sweep/. Accepted candidate is lift12. The repeatable current fixture is godot/tests/camera_composition.gd; it refuses headless rendering and uses paired before/after layouts.

Controller19 and interaction7 regressions pass. A real injected-input resonance journey with V, right-look, pause and Continue passes at evidence/journey-graphical-2026-09-21T03-52-00-995Z/drive.json. Local Web driving/camera/pause/reload proof is evidence/web-camera/cdp-input.json; an actual1280x720 first-person screenshot is retained alongside it.

## Download footprint
Runtime reference search found no use of assets/first-contact-v3.png in project/scenes/scripts/shaders/Web shell. Its source is retained; only export presets exclude it. PCK fell from14,674,668 to12,904,636 bytes (1,770,032 bytes saved). No runtime terrain texture or model was downscaled or removed.

This is a readability/package improvement, not completion of the30-minute content or market visual gate. Current private release identity must be read from evidence/latest-release.json.
