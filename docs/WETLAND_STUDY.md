# Wetland reaction comparison and shallow pool

The two Veil field notes now form one ordered investigation. Activate the sampler at `marsh_reed`; use throttle near Aeral, brake and press E to record its alarm; stay quiet and press E once it recovers; return to `marsh_pool` to validate the pair. Only actual successful Aeral observations count. Wrong species, calm-first observations and invalid values do not advance the study. The existing16sites/finale requirement remains; completed older field notes are preserved by schema11 migration.

The compass follows Aeral while a sample is missing and the basin once both samples exist. Manual journal tracking still takes priority. The pond canopy opens only after field validation; pause, Continue and reset retain or clear the correct state. Transient creature alarm is not a recorded sample by itself.

## Scene and provenance

- Localized10m bowl at `(path_x(-342)-32,-342)`,1.2m depth,4.2m shallow opaque water. The original height formula is preserved outside that radius. The terrain collision uses the same height query.
- World-controlled shader clock freezes on pause. Shore membranes unfold after validation.
- Previously downloaded Ground037 is now copied into active runtime assets. Its bundled asset_licenses.txt explicitly identifies CC0 and the ambientCG source. OriginalPNG bytes match recordedSHA256; mipmaps enabled and packed alpha preserved as data. Rock023 and local authored rock meshes are reused. Terrain3D remains outside runtime.
- Pond rock omissions consume the original random draws first, preserving unrelated procedural placements.

## Actual checks

- Native graphical input journey: 130.441s,9checks,7screens; `evidence/journey-graphical-2026-09-21T10-35-38-553Z/drive.json`. No teleport; includes pause, partial/completed Continue, first/third-person and reset.
- Fresh local Web input journey: 152.442s,8checks; `evidence/web-wetland-final/web-wetland.json`. Includes cold start, both observations, field validation, two reloads and clean console.
- Focused navigation fixture:7checks; `evidence/wetland-study/guidance/guidance.json`. Native graphics preceded the guidance-only fix; finalWeb uses it.
- Thirteen regression suites pass; study15rules, activity123assertions. Font490characters. Stored logs under `evidence/wetland-study/`.
- Final Web PCK14,991,672bytes. Ground037 runtime import is512px; original1024px PNGs remain byte-identical. Native final visual fixture inspected; final Web cold-start/driving/pause/Continue smoke passes. The152.442s full study run preceded this texture-only change. Evidence: `evidence/handoff-final-web/smoke.json`, `evidence/wetland-study/final-512/visual.json`.

The first Web driver went straight from the sampler into a nearby physical obstacle. It was corrected to return to the clear road; the failure and continued run are retained separately. No collision or game progress was bypassed. The final fresh run passed.

## Delivery boundary

Nova requested wrap-up and existing Codex Sites delivery. Further feature expansion is stopped after publication. MARKET remains PARTIAL: the last whole-game baseline was10m33s before subsequent changes, not30minutes. Target platform, performance, three final whole-game runs and independent-human acceptance remain incomplete. See DELIVERY.md and evidence/latest-release.json for handoff and actual publication.
