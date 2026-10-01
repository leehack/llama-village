"""Llama Village character generator (Blender 5.2). From the repository root:

  blender -b --factory-startup -P tool/blender/build_assets.py -- assets/

writes assets/llama_<id>.glb for the five llamas, assets/dash.glb and the
inspector portraits in assets/portraits/. Append `--only <id>` (a llama
id, `dash` or `portraits`) to rebuild one part.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dash  # noqa: E402
import llama  # noqa: E402
import portraits  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_dir = os.path.abspath(argv[0] if argv else "assets")
only = argv[argv.index("--only") + 1] if "--only" in argv else None

for name in llama.ORDER:
    if only in (None, name):
        llama.build(name, os.path.join(out_dir, f"llama_{name}.glb"))
if only in (None, "dash"):
    dash.build(os.path.join(out_dir, "dash.glb"))
if only in (None, "portraits"):
    portraits.build(os.path.join(out_dir, "portraits"))
