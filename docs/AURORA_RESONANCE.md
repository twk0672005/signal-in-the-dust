# Aurora crystal resonance

## Play
At the optional ridge echo on the left side of Aurora Shelf, first stop and press E to record the echo. Three numbered crystal groups stand behind the echo spire. Press E again to listen, then use 1, 2 and 3 to repeat their order. E replays the current round. The three rounds grow from three to five tones; a wrong answer replays the same round.

The numbered lights and tone readout support play without audio or color recognition. There is no answer deadline. Pause/focus loss freezes the sequence. Looking around or switching cameras does not cancel an active sequence. Driving away restarts the challenge. Completion opens the crystals and is saved; Continue restores the completed pose. Partial round progress is deliberately not saved across reload. New Expedition clears it.

## Scope and provenance
This is one optional activity, not a 30-minute content delivery and not a new finale requirement. The existing 4 surveys + 8 fields finale gate is unchanged. The original full all-content route was approximately 6.5 minutes. Do not add this short test duration to that route as if it were a measured combined playthrough.

Crystal geometry and arrangement are authored locally in world.gd; the material reuses the existing audited CC0 Rock023 texture. Three pitched cues reuse the project's original transmit.wav. The existing rover, signal and rock GLBs are retained. No Terrain3D runtime, external model or new network dependency is introduced. The OFL font subset was regenerated for all 369 current interface characters.

## Architecture
- resonance_sequence.gd: pure deterministic listening/answer/solved rules; bounded event emission, no scene or physics dependencies.
- main.gd: proximity and initial sight-line checks, physical numeric-key input, pause, audio/visual orchestration.
- world.gd: three numbered groups; cue intensity and permanent outward-opening pose.
- expedition_activities.gd: activity schema 5 adds resonance_complete. Schema 1-4 defaults to false. Malformed completion data is rejected before state mutation. Outer save schema remains 2.

## Reproduce
- npm run test:resonance: 11 pure rule checks.
- npm run test:activity-logic: 92 activity/migration checks.
- npm run test:resonance-journey -- --graphical: actual injected keyboard and mouse route from spawn through wrong-answer retry, pause, look-around, solution, and Continue. A fresh isolated save is automatic.
- npm test and npm run test:save-flow: existing behavior and defensive saving.

Native latest graphical evidence: evidence/journey-graphical-2026-09-21T00-56-37-730Z/. This one-minute route is automated evidence, not independent player acceptance. Screenshot review repaired inward-folding crystals and overlapping finished-state numbers. Independent code review repaired camera visibility incorrectly cancelling active listening.

Browser evidence lives in evidence/web-resonance/. Early automation attempts hit an actual side-route obstacle, confirmed by a bounded native probe at the browser coordinates. Rounded-hull and grounded-velocity experiments did not resolve it and were fully restored; rover.gd is unchanged. Browser retry evidence must be reported as a continued run after a detour, not a fresh uninterrupted journey.

Release metadata lives in evidence/latest-release.json; do not infer publication from successful local tests. MARKET remains PARTIAL because total content, broad visual quality, target-platform and independent-human gates remain unmet.
