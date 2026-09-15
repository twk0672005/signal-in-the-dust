
## Resume audit — 2026-09-09

- autonomous-work: USEFUL; repaired the false continuation-provider claim and separated wall-clock budget from host limits. Rule still needed: current Codex task cannot claim unattended elapsed time without verified heartbeat/automation.
- product-manager-loop: USEFUL; keeps MARKET PM completeness as terminal gate. Still PARTIAL because no fresh independent audience review/PROCEED decision.
- game-engine-director: USEFUL; keeps first playable as checkpoint and prioritizes the largest market gap.
- game-production-workflow: USEFUL; required fresh runtime journeys, screenshots, and renderer metrics. Current fresh direct Chrome run exposes cold-frame readiness gap.
- ai-game-production-loop: USEFUL as compatibility/reference layer for runtime, visual, and performance evidence; no additional mutation required this pass.
- verification-before-completion: USEFUL; downgraded claims whose fresh evidence did not match (cold splash is not runtime proof).

## Rules to update or connect

1. Keep `RUN_CONTRACT.md` continuationProvider explicit and verified per session; never inherit a native-goal claim from an older thread.
2. Add a maintained cold-start browser check that waits for `window.__GAME.state().ready` and fails on splash-only captures.
3. Keep bundle-size warning and mobile worst-frame spike as PM blockers until fresh metrics are captured after readiness.

## Runtime blocker repair — 2026-09-09

- verification-before-completion: directly useful; forced a real CDP/runtime proof instead of treating screenshots or Chrome process presence as sufficient.
- game-production-workflow: directly useful; the new harness executes named journeys and records state plus renderer metrics.
- autonomous-work: directly useful; wall-clock budget remains separate, and the harness is a current-session observable provider. Automatic heartbeat continuation is still host-dependent.
- game-engine-director / product-manager-loop: still active; runtime proof advances P4 but does not grant PM MARKET PASS.

New maintained surface: `npm run runtime:proof` -> `evidence/runtime-proof/report.json` plus desktop/mobile captures. It starts and cleans up Vite/Chrome CDP itself, so the earlier absent-handle blocker is reproducible and repairable.

## Autonomous continuation repair — 2026-09-09

Machine-wide `autonomous-work` was updated with a continuation handshake rule:
automation configuration and active goals are not elapsed-time evidence; only a
persisted observed continuation receipt may increase `budgetConsumedMinutes` or
support a three-hour claim. A backup is stored at
`C:\Users\tsang\.codex\maintenance-backups\autonomous-work-20260909T1215Z`.

## Claude Code port decision — 2026-09-09

- `自主工作`, `ai-game-building`, and `ai-game-production-loop` are already discoverable Claude-native skills under `C:\Users\tsang\.claude\skills`.
- `C:\Users\tsang\.codex\skills\autonomous-work`, `product-manager-loop`, `game-engine-director`, and `game-production-workflow` are Codex-side operating contracts with valid frontmatter, but their bodies reference Codex-only `/goal`, `codex_internal_context`, Codex agents, Codex memory, and `codex-parallel-workflows`.
- Decision: **copy/port, never move** if future Claude discovery is needed. Keep Codex originals authoritative for Codex. Do not create raw duplicate files that can drift or execute unavailable runtime instructions.
- This run used the existing Claude-native skills plus direct read of the Codex contracts; no global raw copy was made. The current project remains runnable and both runtimes retain their own valid route.
- Verification: the `claude-code-guide` read-only review cited Claude Code official skills discovery as `~/.claude/skills`, project `.claude/skills`, or plugin, and confirmed the Codex-only boundaries.

## Claude-native adapter migration — 2026-09-11

- Created four Claude-discoverable adapters, preserving the Codex source contracts:
  - `C:\Users\tsang\.claude\skills\autonomous-work\SKILL.md`
  - `C:\Users\tsang\.claude\skills\product-manager-loop\SKILL.md`
  - `C:\Users\tsang\.claude\skills\game-engine-director\SKILL.md`
  - `C:\Users\tsang\.claude\skills\game-production-workflow\SKILL.md`
- Each adapter uses Claude-native project contracts/artifacts, `Agent`/bounded lanes, fresh runtime evidence, and explicit PM/engine/production boundaries; none raw-copies Codex-only runtime instructions.
- Discovery load verification: all four adapters were loaded through Claude skill discovery in this session.
- Static/application verification: fresh independent verifier PASS; all four files exist with valid frontmatter, source references, Claude-native mapping, and no banned raw runtime/TODO/test patterns. Pressure scenarios confirmed no premature close, no MARKET promotion from build/screenshot alone, and required one-engine contract/fixture/real-input/adverse/repair evidence.
- Codex app-server lifecycle work remains deferred exactly as Nova requested.

## Codex app-server lifecycle audit — 2026-09-11

- Authorized action completed: one graceful Desktop reopen. Before the action Desktop was already stopped (`app-server=0`, `Codex CLOSE_WAIT=0`); the official AppX identity was used to reopen it. No config, MCP, provider, credentials, workspace, session, rollout, database, or process-child mutation was performed.
- Post-restart read-only baseline: `OpenAI.Codex 26.903.8094.0`, `app-server=1`, helpers `24`, Codex `CLOSE_WAIT=0`, logs total `330.43 MiB`.
- Fresh UI probe completed without Delete: searched `CLOSE_WAIT`, opened `調查更新後 Codex 步驟消失`, and selected `封存` (Archive); the UI returned to a new conversation.
- Required 60-second post-archive snapshot at `2026-09-11T06:50:56Z`: app-server `1`, helpers `28` (`node=14`, `node_repl=5`, `command_wrapper=8`), Codex `CLOSE_WAIT=12`. Against the Phase A snapshot (`36/18/6/11/4`), the delta was helpers `-8`, node `-4`, node_repl `-1`, command_wrapper `-3`, and CLOSE_WAIT `+8`.
- The helper reduction coincided with archive, but the CLOSE_WAIT increase and ongoing activity do not establish thread-level teardown causality or a fix. Audit still points most strongly to app-server resource ownership/teardown; the exact connection-pool path remains unproven. The Desktop version also reported `26.903.9818.0` in the post snapshot, so this is not a perfectly same-build comparison.
- Safe boundary remains: do not guess protocol, launch a second app-server/CLI, force-close sockets, kill helpers, edit the staged binary/config, or touch live sessions/rollouts. Actual root repair belongs upstream; user-side work remains diagnostic-only unless Nova authorizes a verified broker path or patched upstream build.
