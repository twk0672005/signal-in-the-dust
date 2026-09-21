# Current checkpoint
updatedAt: 2026-09-21T00:08:02.660030+00:00
status: PARTIAL / IN_PROGRESS
root: C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906

## Current product and latest evidence
- Godot 4.7.2 Compatibility; first/third-person, 24 m/s cruise, 4 required surveys, 4 optional echoes, 8 field notes, 3 observed species.
- Finale currently requires 4 surveys + 8 fields. Optional echoes remain optional for players; all-content test visits all 16 sites.
- Three injected-keyboard all-content routes reached ending without teleport: 389.013s headless, 393.421s graphical, third ~389s via new command. See evidence/journey-recovery/receipt.json. One graphical route, not three human/platform runs.
- Native 1440x900 actual captures: evidence/journey-graphical-2350/. The map remains visually sparse and the cockpit/landmarks need work. MARKET is not visually accepted.
- Browser cold start reached real Godot menu; physical-key CDP movement >93m, V, pause and reload/Continue restored location/distance/camera. evidence/web-recovery-2355/cdp-input.json. HeadlessChrome 152 only, not the requested platform matrix.
- 88 pure activity assertions, 24 runtime assertions, 17 defensive save-flow assertions. Intentional timeout writes failure and exits1: evidence/journey-timeout-proof/drive.json.
- Font regenerated for 351 interface characters; no missing glyphs. Preserve original OFL source.

## Corrections to earlier claims
- 30 minutes is the target, not implemented playtime. Player shell duration promise removed; existing current route is approximately 6.5 minutes even covering all activities.
- Prior local browser reads of desktop_required were shell checks, not successful game cold starts.
- Headless driver awaited rendering during screenshots. Save/resume was not proven to cause the stall. The persistent repaired driver now skips headless captures and records stages each second, with in-engine and process timeouts.
- The native app Goal tool was observed blocked with generic objective '自主工作模式'; prior docs claiming active were stale. Foreground project work continues under the authorized contract; do not invent Goal completion or unattended duration.

## Release
- Last confirmed before this source repair: private Sites v10 / 57bb86c25d23f6fbaa71498dc1d710787037bdc9, deployment appgdep_6ab0653428e081919179a7b399fb4beb succeeded.
- Read evidence/latest-release.json when present for the subsequent deployment receipt. It is outside source commits to avoid rebuilding solely for receipt bookkeeping.
- No existing push/owned Godot job is assumed live. Reconcile actual status before publishing. Existing preview PID18752 was left untouched.

## Next product work
- Main missing gate is content, not another counter: build distinct multi-step ecological observation/puzzle sequences and authored side trails using reviewed assets, then measure real pacing. Do not add mandatory idle waits or reduce the authorized vehicle speed to fill time.
- Retain existing reversible candidate and snapshots; integrate new content in one region first before extending to four.
- Still missing: ~30-minute meaningful content, 3 human-like full journeys on final content, full save persistence journey, Windows Chrome/Edge/Firefox and macOS Chrome/Safari, export performance and independent first-time human review.

## Reproduce
- npm run test:journey (headless input route with unique evidence folder; 15-minute internal watchdog and 930-second process bound).
- npm run test:journey -- --graphical (1440x900 actual screenshot route).
- npm run check; npm run test:activity-logic; npm test; npm run test:save-flow.
