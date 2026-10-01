# Character generators

Blender 5.2 scripts (tested with 5.2.2 LTS, bundled glTF exporter only) that
build the characters from code. From the repository root:

```bash
blender -b --factory-startup -P tool/blender/build_assets.py -- assets/
```

This writes `assets/llama_<id>.glb` for Pip, Mo, June, Bramble and Clover,
`assets/dash.glb` and the inspector portraits `assets/portraits/<id>.png` in
a few seconds. Append `--only <id>`, `--only dash` or `--only portraits` to
rebuild one part (portraits are rendered from the glbs, so rebuild them after
a llama). `test/render/character_assets_test.dart` checks the results.

| File | Role |
| --- | --- |
| `build_assets.py` | Entry point. |
| `llama.py` | The llamas: per-llama parameters (`LLAMAS`), metaball bodies, face with expression morphs, accessories, the shared skeleton and the clips. Adapted from the Llama Whisperer generator. |
| `dash.py` | Dash: body, wings, tail, face, rig and clips. |
| `portraits.py` | Head-and-shoulders portraits (EEVEE, transparent). |
| `geo.py` | Mesh builder for details: per-vertex colours, bone weights, morph positions. |
| `common.py` | Materials, export, and stripping the procedural bones' channels. |

## Conventions

- glTF is Y up, metres; characters face glTF +Z. flutter_scene 0.23.0 negates
  Z on import, so in the game they face -Z.
- Every llama has the same bones and hierarchy; each body moves the joints to
  fit, and every glb carries its own `Idle`, `Walk` (that llama's gait) and
  `Gallop`. The game drives `neck_aim`, `head_aim`, `ear_*`, `lid_*`, `tail`,
  `scarf` and `belly` itself, so the export strips their channels.
- Colours are vertex colours (`Col`); materials only name the finish
  (`Wool`, `Hoof`, `EyeGloss`, `EyeShine`, `Face`, `Cloth`, `Gloss`,
  `Feather`), which `lib/render/character_rig.dart` tunes.
- Face morphs, in order: `Happy`, `Sulky`, `Surprised`, `Sleepy`, `Talk`
  (Dash: `Happy`, `Sad`). Blinks and lids are the `lid_*` bones, turning
  `LID_OPEN - LID_SHUT` degrees from open to shut.
- Accessories are rigid meshes parented to bones: `Acc_head`, `Acc_neck`,
  `Acc_spine`, and Pip's `Scarf` (neck) and `ScarfTail` (scarf bone).
- Walk clip lengths and strides are mirrored in `llamaSpecs`
  (`lib/render/llama_rig.dart`); the asset test checks the lengths.
