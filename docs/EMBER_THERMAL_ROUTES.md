# Ember — observe, choose and change the habitat

The existing warm-shelter escort remains available. The eastern vent now reveals an alternative cool mineral trail. Players can observe it before meeting Veyra: approach the vent beside the Ember echo, stop and press E during the bright plume. A second E selects the cool trail; E toggles the route until escort starts. Survey/echo interaction retains priority when it is available.

After observing Veyra and completing Ember's required survey, return to the lead animal and press E. The choice locks for this expedition. Warm follows the original route and warms its shelter. Cool follows seven authored points through the western mineral area to (-60,-145); that bed lights and the other three Veyra gather there. Pause, intermediate Continue, completion Continue and confirmed reset preserve/clear the chosen outcome correctly. Global24m/s driving remains unchanged.

Only existing authored rocks and verified CC0 materials were reused. The vent uses three inexpensive translucent steam meshes; animation freezes with the world. Current presentation remains a prototype-level habitat and still needs authored detail and migration-animation polish.

## Storage repair found during actual Web play

The first two Web cold-route journeys exposed a reproducible persistence failure: the paused escort read 95.615551m and the in-memory save snapshot matched, but reload restored 73.946818m from an older autosave. The failed receipts are preserved. Three generic pause/reload probes passed, so they were not used to dismiss the route-specific failure.

Web expedition records now use synchronous origin-scoped Web Storage under a game-specific key. The temporary record is validated; a valid previous primary is backed up; primary replacement is read back exactly. Native FileAccess storage is unchanged. An untouched Web slot migrates the previous userfs record. A reset tombstone prevents that legacy record reappearing after immediate reload. If clear fails with a readable old checkpoint, reset is refused and the old progress is preserved with an explicit warning. Players with no save can still play when storage is unavailable, with a visible warning; saving can recover once storage works.

Background: [Godot Web persistence notes](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence). The actual failure and fix claims here are based on this project's browser readbacks, not an assumption about every browser. These tests cover page reload and storage errors; they do not claim OS power-loss guarantees.

## Fresh proof

- Native cold route: 168.744s,14checks,7screens; `evidence/journey-graphical-2026-09-21T08-11-16-856Z/drive.json`. This predates the Web-only storage changes.
- Original warm route: 193.652s headless input regression; `evidence/journey-headless-2026-09-21T08-18-46-118Z/drive.json`. Its approach differs, so do not compare these durations as a route-length benchmark.
- Final Web cold route: 233.007s,13checks; `evidence/web-thermal-fixed/web-thermal.json`. It discovers the vent before the species survey, pauses/reloads at three points, then completes and reloads the outcome.

| Paused escort metres | Restored metres |
|---:|---:|
| 45.369053 | 45.369053 |
| 95.396653 | 95.396653 |
| 145.311515 | 145.311515 |

- Actual old-save migration4checks, isolated storage fault7checks, disabled-storage/play/recovery5checks. Fault injection is a separate storage fixture, not gameplay proof. Evidence paths are in `evidence/thermal-route/receipt.json`.
- Twelve regression suites pass: thermal15, activity116, controller19, interaction7, ecology25, runtime24, save9, save-flow19, resonance11, escort18, passage23, roots17. OFL subset472characters.
- Web PCK 12,967,820bytes. Gzip WASM decoded against raw export; all manifest SHA256 values verified.
- Final error-warning-only UI changes were checked with the disabled-storage fixture after the full cold-route run. The receipt records this evidence boundary.

## Remaining target

MARKET remains PARTIAL. The last complete combined route was10m33s before this fork. This adds a meaningful persistent choice, not proof of30minutes. Next: region-specific two-stage field investigations and authored reconnecting side loops, followed by a combined timed playthrough. Actual human/platform/performance/art gates remain open. `evidence/latest-release.json` is the authority for the hosted version.
