# Implementation Plan: Luminous alien-world showcase
**Branch**: codex/veil-marsh-visual-upgrade | **Date**: 2026-09-23 | **Spec**: [spec.md](spec.md)

## Summary
Preserve the game and deliver a continuous portfolio journey using the existing integrated world as the candidate. Repair observed appearance and interaction gaps in context; do not wait for isolated asset approval before assembly.

Workflow maintenance update, 2026-09-24: this plan describes the next authorized continuation only. The one-hour run has ended and worker source is frozen; this edit does not resume production or grant publication. Its original [run contract](../../evidence/product-hour-20260924-155123/RUN_CONTRACT.md) and [worker handoff](../../evidence/product-hour-20260924-155123/worker/HANDOFF.md) remain unchanged evidence.

## Technical Context
GDScript/Godot shaders and existing HTML/CSS/JS shell; Python/Blender asset authoring. Godot4.7.2 Compatibility single-thread Web; Blender5.2.1 LTS. Source HEAD8d4e864effde0ca75556419f747310183b42e028.
Storage: existing expedition_save/activity schemas and settings, no external services.
Testing: package.json checks, exported real controls, native graphical fixtures, disposable Blender->GLB->Godot probe and profile.
Budgets: standard1080p60FPS/p95<=25ms; low720p>=30FPS. Current build rejects single files>25MiB.
Scope: four habitats, three established large species plus concept-pending fourth, six flora, two micro-fauna categories, home/UI.
Continuation: current-session preparation; PM stage routing, no added heartbeat or token/time budget.

## Constitution Check
Preparation PASS: same engine/source, protected controls/saves, local assets. Explicit current mobile/free-exploration brief supersedes older desktop-only/mandatory progression assumptions. No authority file rewrite or publication. Recheck after merged brief.

## Project Structure
- godot/scripts/world.gd + narrow visual modules: habitat/species presentation and existing response integration.
- godot/shaders/ and godot/assets/: runtime resources; art-source/: reproducible asset source.
- godot/web/shell.html + tools/web-build.mjs: PCK-external artwork and one-shot launch flow.
- godot/scripts/interface.gd/main.gd: scoped guidance/map/intent/optional-progression changes.
- specs/002-veil-marsh-visuals/: lineage, tasks, contracts.
- evidence/visual-upgrade-20260923/: preserved baseline and separate native/Web/probe receipts.

## Dependency Sequence
1. On authorized resume, read the latest integrating PM receipt and open the current candidate. Reuse valid baseline/tool/import evidence; rerun a probe only for a changed or unresolved boundary.
2. Compare representative four-region views and the entry/exploration journey against the current art brief. Rank concrete player-visible gaps across shape, material, light, environment and interaction.
3. Repair the highest-impact gap in the integrated candidate, preserving behavior interfaces. Isolated lookdev and side/rear checks are internal diagnostics, not approval prerequisites for assembly.
4. Export representative changes early to the actual Godot Web renderer; use the existing journey and profile tools to expose handoff losses and performance costs.
5. Deliver one complete candidate for consolidated art/PM findings; repair evidenced defects and recheck affected views and behavior.

## Final export and evidence on the next authorized run

The worker handoff recorded a missed cutoff and three final visual repairs with only parse/controller checks and no fresh capture. On resume, reconcile these gaps against the latest PM evidence; the worker receipt alone does not establish an accepted finish.

- Before authoring, the integrator and worker use observed export/test durations to reserve a final verification interval within the user-authorized budget. Record the internal handoff cutoff in the existing run contract; do not invent a new user duration or restart the expired clock.
- Keep the openable integrated candidate available throughout. If handoff slips, use the remaining time for the required export and verification and report unfinished polish as PARTIAL, rather than consuming the interval with optional edits.
- Bind the delivered source and Web artifact hashes to the final captures, input journey and profile. A later material/light/geometry change requires refreshed affected Web captures and, when rendering cost may change, a fresh profile; unaffected evidence can be reused with a stated basis.
- Verify representative four-region views and real Web controls, plus save/mobile/low-quality behavior affected by the changes. Record device, viewport, quality tier and frame-time distribution against existing targets. Native fixtures alone cannot clear Web visual/performance claims.
- Integrator owns the final export and consolidated verdict. Missing or failing checks remain PARTIAL; no additional per-asset approval chain is introduced.

## Probe Contract
Unshipped two-bone membrane coupon tests geometry, UV/normal, alpha/emission and animation transfer. All output stays in ignored evidence; it is not a creature, art-delivery or new game scaffold.

## Complexity Tracking
No general event bus, external AI, replacement physics, weather/food-web simulation or alternate engine.
