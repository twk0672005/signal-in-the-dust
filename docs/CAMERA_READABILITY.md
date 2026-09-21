# First-person view and export cleanup

The sensor mount is raised from 1.40m to 1.48m. Its fore-aft position, pitch and FOV are retained. The rover controller, physics and third-person rig were not altered.

## Evidence
At matched terrain-settled poses at1440x900, real rover-only white render masks gave:
- Spawn:25.232% of viewport before,15.999% after.
- Ridge:22.118% before,13.389% after.
- Rift:23.311% before,14.622% after.

These are staged composition measurements, not full-route occlusion guarantees. A small peripheral housing edge remains in some poses. The more elevated/forward candidates were rejected because they removed the bonnet entirely. A per-part sensor layer experiment was removed after verifying the existing rover GLB has a combined body mesh.

Raw before/after images and masks: evidence/camera-composition-sweep/. Accepted candidate is lift08. The repeatable current fixture is godot/tests/camera_composition.gd; it refuses headless rendering and uses paired before/after layouts.

Controller19 and interaction7 regressions pass. A real injected-input resonance journey with V, right-look, pause and Continue passes at evidence/journey-graphical-2026-09-21T04-21-23-150Z/drive.json. Local Web driving/camera/pause/reload proof is evidence/web-camera-final/cdp-input.json; an actual1280x720 first-person screenshot is retained alongside it.

## Download footprint
Runtime reference search found no use of assets/first-contact-v3.png in project/scenes/scripts/shaders/Web shell. Its source is retained; only export presets exclude it. PCK fell from14,674,668 to12,904,652 bytes (1,770,016 bytes saved). No runtime terrain texture or model was downscaled or removed.

This is a readability/package improvement, not completion of the30-minute content or market visual gate. Current private release identity must be read from evidence/latest-release.json.

Final live Web slope inspection rejected the12cm lift because it brought the sensor housing into the upper view. The accepted8cm lift retains the measured ground-visibility gain with more head clearance.
