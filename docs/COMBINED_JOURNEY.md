# Combined expedition and discovery journal

## Measured result

The first successful continuous native input journey completed all4encounters,4required surveys,4echoes,8field notes,3species observations and the finale in **633.1seconds (10m33s)**. It did not teleport, restore a save, or mutate game progress.19actual1440x900images are retained. This is an informed automated driver, not a novice human playtime measurement and not30-minute content proof. Waypoint stops and screenshots are included.

| Milestone | Segment seconds | Cumulative seconds |
|---|---:|---:|
| arrival_complete | 6.8 | 6.8 |
| aurora_complete | 92.4 | 99.2 |
| ember_complete | 166.7 | 266.0 |
| veil_complete | 152.0 | 418.0 |
| pale_complete | 180.4 | 598.4 |
| ending_complete | 34.7 | 633.1 |

Command: `npm run test:combined-journey -- --graphical`. The separate `combined_drive.gd` reuses input/navigation helpers without changing the independent encounter tests. Its watchdog allows30minutes but does not wait to manufacture duration. `tools/run-journey.mjs` records source SHA256 before launching, plus progress, failures and completion.

The first baseline attempt stopped at322.325s because a straight return from the marsh echo hit a visible membrane bank. The driver now goes around its north side; the collider remains. This is distinct from the earlier fixed main-road intrusion.

## New player-facing journal

Press **J** or select the journal from Pause. Four region rows show unknown, available or complete encounter status. Entering a region makes its encounter discoverable. Select Track to direct the existing compass toward its prerequisite or live encounter target; select Track main surveys to return to automatic survey guidance. Opening the journal pauses simulation and clears driving input; Esc/Resume closes it.24m/s cruise and finale requirements are unchanged.

Tracking adapts to Ember observation/survey prerequisites, the moving Veyra, the next Veil opening, and the first unpowered Pale junction. Encounter completion clears tracking. Activity schema9 stores discovered regions and the selected encounter; versions1–8 migrate from current/completed regions. Invalid or undiscovered tracking is rejected before load mutation.

Native journal14checks pass with actual keyboard and injected viewport mouse events; two languages and960x600captured. The coordinate fixture follows [Godot Viewport input coordinates](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-push-input). The first unsuccessful pointer-coordinate fixture is preserved. Local Web9checks pass: real J, screenshot-grounded mouse selection, movement, reload/Continue, cancellation and clean console. No game state was written from browser JavaScript.

## Evidence

- Combined source-bound journey: `evidence/journey-graphical-2026-09-21T07-19-43-025Z/drive.json` and `provenance.json`.
- Native journal: `evidence/journal-native-02/journal.json`.
- Web journal: `evidence/web-journal/web-journal.json`.
- Full receipt and Web hashes: `evidence/combined-route/receipt.json`.
- Eleven existing regression suites pass; activity/migration now112assertions, font subset445characters.
- Read `evidence/latest-release.json` for actual private deployment status.

## Next content slice

MARKET remains PARTIAL. Navigation now exposes the encounters, but the combined result still demonstrates a short expedition. Add an Ember observation-to-choice branch using the existing warm seam/vent ecology, with an actual alternative route and saved ecological outcome, then measure again. Reduce repeated field actions and repeated prop placement with region-specific ecological investigations and authored side loops. Preserve global speed and free access; do not pad with mandatory waits or convert test duration into a human30-minute claim.
