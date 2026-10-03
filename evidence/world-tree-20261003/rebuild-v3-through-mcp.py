from pathlib import Path

source = Path(r"C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906/art-source/world_tree_20261003_v3/build_world_tree_v3.py")
code = source.read_text(encoding="utf-8")
exec(compile(code, str(source), "exec"), {"__name__": "__main__", "__file__": str(source)})

