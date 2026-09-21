# Veil Marsh — quiet membrane passage

The player drives through five ordered membrane openings while keeping the Aeral flock calm. This is an optional route; the rover retains 24 m/s global cruise speed and every region remains freely reachable.

## Play

- Enter Veil Marsh and follow the bilingual passage arrow to the first lit opening near z=-235.
- Stop within 14 m, face the opening and press E.
- Cross each lit opening below 5.5 m/s. Completed membranes unfold and the next opening lights.
- Approaching above 5.5 m/s within 12 m scatters the flock. Leave the current opening's 8 m radius, then return quietly after the brief alarm settles. Earlier openings remain complete.
- Finish all five to open the passage and draw Aeral back down into the membrane shelter.
- Esc pauses all passage motion. Continue restores an unfinished passage or its completion. R confirmed reset clears it.

## Implementation

Pure `quiet_passage.gd` owns ordered gates, alarm and one-shot events. `world.gd` owns five authored membrane assemblies and flock poses; it alone advances animation. Material inputs are the existing verified CC0 Rock023 maps. No new downloaded assets or native extensions enter runtime.

Activity schema7 migrates schemas1–6 with an empty passage. Nonempty state validates phase, finite positions, integral counters, completion consistency and exact current route before changing the live game. The outer expedition save remains version2. Failed storage displays a bilingual warning and leaves gameplay usable; Continue can return to an older checkpoint.

## Fresh proof

- Pure passage23 checks; activity/migration101; controller19; interaction7; ecology23; runtime24; save9; defensive save-flow19; resonance11; escort18. Logs: `evidence/marsh-passage/`.
- Native injected keyboard, no teleport: 114.075s including the approach, 11 checks, seven real screenshots. `evidence/journey-graphical-2026-09-21T05-19-03-682Z/drive.json`.
- Local Web physical-key CDP, no state mutation: 208.458s, cold start, fast-entry recovery, pause, mid-reload Continue and completed-reload Continue. `evidence/web-passage-pulsed/web-passage.json`.
- New Web PCK: 12,924,632 bytes. Manifest hashes verified; compressed WASM exactly matches raw export after decoding.
- Source and artifacts: `evidence/marsh-passage/receipt.json`. Source backup: `evidence/marsh-passage/before/`; full baseline is commit4679651.

## Boundaries

This is not 30-minute content proof. The approach overlaps previous journeys. The first two approach tests failed outside activation range; another test asserted before deferred Continue and decelerated too early to exercise the intended fast-entry condition. Their failure receipts remain. The final route fixes the driver and passes without weakening the gate rules.

Actual screenshots show the reactions, but repetitive props, sparse environment and small-window text still need visual work. Windows HeadlessChrome local proof does not cover the required Chrome/Edge/Firefox/macOS matrix or independent human acceptance. MARKET remains PARTIAL. Read `evidence/latest-release.json` for actual hosted status.
