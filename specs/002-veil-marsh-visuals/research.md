# Preparation decisions
- Preserve exact baseline/worktree, no second checkout.
- Binary read-back: Godot4.7.2.stable.official.ed1daf0bf; Blender5.2.1 LTS hash9e2066aef7ef; Python3.11.9; Nodev24.15.0.
- Official renderer reference: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- Official import reference: https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html
- Matching Blender5.2 web manual retrieval failed. Verify exact options using installed bundled io_scene_gltf2/RNA and a disposable export; no new add-on/provider.
- Preserve alpha and intended animation scales; one owner per runtime transform.
- Shell progress counts decoded asset bytes, not compile/scene readiness. Single-thread initialization can stall animation.
- Existing W accelerates at9m/s^2 to24m/s road/16.5m/s off-road; no redundant boost.
- Exact concept anchors/fourth species remain a PM/art dependency, not a blocker to tools/baseline.
