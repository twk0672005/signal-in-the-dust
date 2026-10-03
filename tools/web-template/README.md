# Same-version Web template

The checked project template is `godot/build-templates/web_nothreads_release_parallel.zip`. It is Godot4.7.2-stable, Compatibility/GLES3, single-thread Web, no GDExtension. The official source/tag, exact five-file patch, portable toolchain and build identities are retained here and in `evidence/startup-clear-20261003/custom-template/sealed-01/`.

`prepare.py`, `patch_source.py`, then `build.py` reproduce the template with project-local official Emscripten4.0.20 and SCons. Build-host response-file quoting is included for Windows. These scripts create an isolated source/toolchain beside themselves, without global activation. Use a separate disposable copy for reproduction. `SEAL.json` identifies the accepted ZIP and decoded WASM; `INTERFACE.md` documents status/readiness requirements. A build does not prove browser or visual behavior.

The patch uses lazy scene variants and genuine KHR completion polling; unsupported-extension and non-scene shaders remain synchronous. The game waits for an error-free stable rendered view/reflection sweep. See `docs/STARTUP_2026-10-03.md` for actual tests and platform limits.
