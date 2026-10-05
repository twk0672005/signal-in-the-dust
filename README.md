# 異星漫遊 | Alien Wander

Working title proposed for the 2026-10-04 free-exploration revision, not a final
brand decision. Drive a rover through Aurora Shelf, Ember Rift, Veil Marsh and
Pale Decay. Leave the road, watch alien life, stop at a landmark, and keep roaming.

There is no assigned route, mission tracker, countdown or mandatory world-tree
ending. Nearby optional observations show a named subject and cause a local
response. The journal keeps observations; it is not a checklist.

## Active Source

- Godot 4.7.2, Compatibility, single-thread Web export.
- Main scene: `godot/main.tscn`.
- Runtime: `godot/scripts/main_web_20261003.gd`.
- `main.gd` is a compatibility alias to the same runtime.
- Current contract/evidence: [Alien Wander checkpoint](docs/ALIEN_WANDER_2026-10-04.md).
- Source branch: `codex/alien-wander-20261004`, based on `87f4de7`.
- Original assets, provenance records, historical branches and immutable releases
  remain in place. The earlier Three.js project is not the active game.

## Local Play

`npm run build` writes a new versioned local artifact and updates `out/` for
preview, preserving prior immutable release directories. `npm run dev` serves
the current local preview at `http://127.0.0.1:4174/`. Use another port when that
port is occupied:

```powershell
python tools/serve_web.py --port 0
```

Controls: WASD/arrows drive, S brakes then reverses, Space brakes, C crawls,
Shift accelerates, right-drag looks around, V changes camera, E optionally
observes, J opens observations, Escape pauses. Parked camera direction is retained.
Landscape touch has independent steering/pedals, camera, observation and drag look.

## Brand And Saves

Visible product names and shared introduction copy are in
`godot/config/brand.json`. The Web build derives its brand script and metadata
from this file; Godot uses the same data.

The internal Godot project name, `user://expedition_state.json`,
`user://expedition.cfg`, and the `signal-in-the-dust:expedition:v2:` Web prefix
are intentionally unchanged. They are storage identity, not visible branding.
Version 1/2 saves and older activity schemas remain readable. Old observations
are migrated into the optional journal without discarding legacy fields.
Continue uses the existing checkpoint; starting anew still requires confirmation.
Corrupt primary files can recover from the prior valid generation.

## Checks

```powershell
npm run check
npm run test:controller
npm run test:interaction
npm run test:ecology
npm run test:save
npm run test:save-flow
npm run test:combined-journey -- --url=http://127.0.0.1:4174/
node tools/alien-wander-web-qa.mjs --touch --url=http://127.0.0.1:4174/
```

The combined browser journey uses real keyboard/pointer input, never teleporting,
a review camera, or injected game state. Native tests use explicit isolated
fixtures and cannot substitute for that journey. Historical activity-rule tests
remain as compatibility evidence; they are not the current product contract.

## Publication

This revision is local until Nova explicitly authorizes a particular public
push/deployment. Existing repository names and public URLs are unchanged.
Previous release approvals do not apply to this candidate. Physical-phone,
Safari and broad hardware performance claims require their own actual tests.
