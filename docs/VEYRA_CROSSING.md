# Veyra quiet crossing

## Play
After observing Veyra and completing the main thermal survey in Ember Rift, stop near the first Veyra and face it. E changes to Accompany Veyra when it is calm. Press E to begin.

Keep 4–24 metres from the companion and drive below 8 m/s. Crowding it or driving too fast makes it stop and fold down. Stop or back away to let it recover. If you move too far away, it waits until you return. The original 24 m/s exploration speed is unchanged elsewhere.

The animal visits a northern warm seam then crosses to the southern mineral shelter. Arrival warms the authored rock bed. The activity is optional and does not change the finale gate. Pause freezes progress; Continue restores the animal's position, waypoint and alarm during an unfinished crossing. Completion is also saved. New Expedition resets it.

## Implementation and provenance
- quiet_escort.gd is a pure deterministic route/stimulus state machine with bounded alarm, finite-input validation, copied route data and one-shot completion.
- world.gd projects the existing first Veyra onto the quiet route and adjusts its posture/light response. All other species retain their original reactions. The companion has its own learned tolerance while escorting.
- The shelter uses existing low-LOD rock meshes and the audited CC0 Rock023 map. No new downloaded asset, runtime Terrain3D extension, service or credential is introduced.
- Activity schema6 adds escort completion and a validated escort_state. Schema1–5 default to no escort. The outer save schema remains2. Restores validate phase, count, cursor, origin, position, alarm, route segment and current world bounds before mutating live state.
- The original rover controller and collision geometry remain unchanged.

## Evidence
Native: evidence/journey-graphical-2026-09-21T02-22-57-924Z/drive.json; actual keyboard, intentional noise, quiet follow, pause, mid-activity Continue and completed Continue. Native route approximately198 seconds includes earlier exploration; it is not the activity-only duration.

Web: evidence/web-escort/web-escort.json; fresh browser route with physical CDP keys and both mid-activity and completed reload. Approximately151 seconds includes approach and observation.

Reproduce:
- npm run test:escort
- npm run test:activity-logic
- npm run test:escort-journey -- --graphical
- npm run test:save-flow

Pure escort18, activity migration96, existing runtime24/save-flow17/interaction7/ecology23 checks pass. The final browser proof includes origin-aware restoration and actual map validation. Independent review identified the observe-action precedence and partial-progress persistence gaps; both were repaired.

MARKET remains PARTIAL. This adds a distinct short encounter, not the requested full30-minute version. Broader map/content work, visual finishing, export performance, target browsers and independent human acceptance are still required. Production release status is recorded separately in evidence/latest-release.json.
