# Legacy merge specification

## User outcome
Preserve the old Signal in the Dust implementation and local assets inside the current DeepSpaceRover/AURELIA project without replacing the active Three.js product route.

## Scope
- Source: `C:\Users\tsang\Documents\ChatGPT\deep-space-rover-three-20260906`
- Destination: `C:\Users\tsang\DeepSpaceRover\deep-space-rover-three-20260906\legacy\signal-in-the-dust`
- Selected local visual assets are copied to `public/assets/legacy-signal-in-the-dust`.
- Active AURELIA `src`, package manifests, contracts and runtime evidence remain authoritative.

## Non-goals
No source overwrite, no package dependency merge, no deploy/publish, no public exposure, no destructive deletion before read-back verification.

## Acceptance
- Legacy source/docs/tests/Godot proof/evidence are readable under the destination namespace.
- New active route still passes its current check/build/runtime proof.
- Legacy asset hashes are recorded.
- Old source root is only retired after destination read-back and verification; if deletion is not separately confirmed, retain the old source as a rollback copy.

## KILL boundary
`KILL` means retire the old source route after verified preservation; it does not mean delete or overwrite the AURELIA route.
