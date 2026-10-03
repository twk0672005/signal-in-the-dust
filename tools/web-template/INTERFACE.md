# Same-version Web template integration contract

This candidate keeps Godot 4.7.2-stable, Compatibility/GLES3, wasm32,
single-thread Web, no GDExtension. Official source commit:
`ed1daf0bf001b61586d9930840f2f1394092c079`. No game shader code, rendering
features, assets, quality settings, light limits or modules are removed.

Only `SceneShaderGLES3` uses asynchronous compilation on Web when
`KHR_parallel_shader_compile` is enabled successfully. Scene variant maps
initialize lazily, then compile the exact variant/specialization requested
by each real draw. Native engine behavior is unchanged. Other Web shader
classes remain synchronous because some of their bind callers cannot safely
handle a pending program. Without the extension, scene compilation also stays
synchronous, while lazy scene variants still avoid the unused base variants.

## Method

`RenderingServer.get_web_shader_compile_status() -> Dictionary`

The getter polls all outstanding scene programs using
`GL_COMPLETION_STATUS_KHR` (0x91B1). It queries vertex/fragment compile
status, link status and uniform locations only after completion signals true.
The previous GL program is restored after uniform setup. It returns:

| Field | Meaning |
|---|---|
| `extension_checked` | Extension availability was tested in the current WebGL context. |
| `extension` | Emscripten enabled KHR_parallel_shader_compile successfully. |
| `async_enabled` | Async scene path is enabled. Equal to extension support. |
| `pending` | Scene programs submitted but not finalized/cancelled. |
| `submitted` | Cumulative async scene submissions. |
| `completed` | Cumulative successfully finalized scene programs. |
| `failed` | Cumulative async compile/link failures; treat any nonzero value as terminal. |
| `cancelled` | Pending programs cancelled because their owning version was cleared/freed. |
| `skipped_binds` | Cumulative scene draw binds skipped because their requested program was still pending. |
| `errors` | First 32 async compile/link errors, with available driver logs. |
| `scope` | Explicit reminder that other shader classes are synchronous. |

Counters cover the engine lifetime. They do not reset between regions/cameras.
`submitted == completed + failed + cancelled + pending` is the intended
accounting invariant. Pending compile does not invalidate the material/version;
the bind returns false so the scene renderer skips that draw. It never
substitutes a specialization whose features/uniform layout do not match.

## Root acceptance requirements

Keep all partial draws hidden behind the existing loading overlay. Batch real
representative material/light/instancing draws across actual frames, then poll
until the queue settles. Replay those submissions, all region views and both
rover cameras. A zero pending count proves only that submitted programs have
finished; an unseen specialization can still be submitted later.

Reflection probes may cache a draw captured while geometry was pending. Force
a final probe refresh after the scene queue settles, then settle any new
submissions and refresh again if the probe pass caused further pending/skipped
binds. Require stable submitted/completed/skipped counts over complete real
views before exposing the world. `frame_post_draw` alone is insufficient proof.

Capture browser engine errors as well as this dictionary: synchronous sky,
effect and fallback shader failures are still reported through the stock engine
error path, outside these async counters. Extension support is context/device
specific. Successful build/static validation cannot prove GPU concurrency,
cold startup target, visual fidelity, reflections, input, or absence of driving
stalls. Root owns those runtime checks and final acceptance.

## Reproduction and rollback

`prepare.py` downloads immutable official archives and records their identities.
`patch_source.py` changes four engine source files plus the Windows Web build
configuration (final-link response file for Windows command-length limits), retains their original
copies in `baseline/`, and writes a unified patch and SHA-256 manifest.
`build.py` scopes toolchain configuration, PATH and temporary files to this
package, then produces a release template. No global activation is needed.
Restore a fresh official archive and apply the retained patch to reproduce;
select the previous stock export template to roll back game integration.

The custom build uses Godot's default `custom_build` label; numeric version and
stable status remain 4.7.2-stable. Source provenance is external and explicit;
the source archive has no embedded Git database.
