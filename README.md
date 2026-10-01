# Llama Village

A small 3D village of AI llamas that live their own lives while you watch
and meddle as Dash, a little blue bird.

Five llamas (Pip, Mo, June, Bramble and Clover) each have a persona, needs,
friendships, goals and secrets. They plan their day, walk the paths
between their huts, the pond, the berry bushes, the bakery and the
hilltop, and stop to talk. What they say is written live by an on-device
language model, one line at a time, and only from what each llama
actually knows. Facts move between them by being seen, told, overheard or
announced, so rumours spread, secrets slip out, and story threads (a lost
red scarf, the Berry Festival singing contest, a secret crush, a bread
rumour and a storm warning) play out differently every run.

## How to play

- **Click a llama**: Dash flies over and starts talking. Four things Dash
  could say appear as buttons (they are written while Dash is flying, so
  they are usually ready on arrival). Pick one (or press 1-4). The llama
  answers in a bubble, and the effects apply: friendship, mood, gifts,
  news it now knows, or a rumour it now believes. "Say more" asks for a
  fresh set; "Fly off" (or Esc) ends the visit.
- **Right-click a llama**: inspect it without talking. The inspector shows
  its persona, mood, needs, friendships, goals, everything it knows (with
  how it learned it: "saw it", "heard from June; maybe untrue", "own
  secret"), its current thought, and why it chose its current action
  (the utilities of its options).
- **Click the ground** or hold **WASD** to fly Dash around. Dash
  witnesses what happens where it hovers, and can pass true news on.
- **Camera**: drag to orbit, right-drag or two-finger drag to pan, scroll
  or pinch to zoom, Q/E to turn. **F** follows the selected llama (or
  Dash), **O** returns to the overview.
- **Time**: Space pauses; the 1×/2×/4× buttons set the speed. One game
  minute is half a second at 1×; the deep night runs faster, and the
  clock waits at dawn while the llamas write the day's plans.
- The **village log** (bottom left) lists events, conversations, who
  learned what, and story-thread turns.
- The **gear** button opens Settings: a frame-rate cap of 30, 60
  (default) or 120 fps (120 only matters on a ProMotion display). The cap
  skips scene renders between display refreshes; the sim and animations
  run on real time, so their speed does not change. Settings are saved
  with shared_preferences.

Speech bubbles show "…" while the model is still writing a line; thought
bubbles (rounded, italic) show what an idle llama is thinking.

## Models

All inference is local, through [llamadart](https://pub.dev/packages/llamadart)
on Metal. Nothing is downloaded at run time.

| Role | File | Required |
| --- | --- | --- |
| Dialogue, plans, thoughts, Dash's options and replies, small JSON outcomes | `gemma-4-E2B-it-Q4_K_S.gguf` | yes |
| Embeddings for checking which facts were actually said | `embeddinggemma-300M-Q8_0.gguf` | yes |
| Laya decision model, for picking casual conversation topics | `laya-Q8_0.gguf` + `laya-head.safetensors` | no |

By default the app looks in `~/Library/Caches/llamadart/models` (and one
folder level below it) for the first two, and in
`/opt/UnitySrc/personal/llama/models/embed-evidence` for Laya. Override any
of them with environment variables or with the same keys in
`~/.config/llama-village/models.json`:

```
VILLAGE_MODELS_DIR    folder to search for the gemma and embedding files
VILLAGE_CHAT_MODEL    full path to the dialogue model
VILLAGE_EMBED_MODEL   full path to the embedding model
VILLAGE_LAYA_DIR      folder with the Laya files
VILLAGE_LAYA_MODEL    full path to laya-Q8_0.gguf
VILLAGE_LAYA_HEAD     full path to laya-head.safetensors
VILLAGE_LAYA=0        skip Laya (topics then come from the rules)
```

If a required model is missing, the loading screen says which file and
where it looked, and offers to play with canned lines instead.

Actions, reactions and knowledge bookkeeping are rules; the model writes
the words. When the model's output does not parse, the sim retries once
with another seed and then falls back to a canned line, so the world never
waits on the model.

## Dev-only: the macOS sandbox is off

The model files live outside the app container, so this development
build turns the macOS App Sandbox off
(`com.apple.security.app-sandbox` is `false` in
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`).
Do not ship it like this: a distributable build should keep the sandbox
and copy or download the models into the container, or ask for the files
through a user-selected security-scoped bookmark.

## Run it

Requirements: macOS 14+, Apple silicon, Flutter 3.47.1 (flutter_scene uses
Flutter GPU, enabled with `FLTEnableFlutterGPU` in `Info.plist`).

```
flutter pub get
flutter run -d macos --release
# or
flutter build macos --release
open build/macos/Build/Products/Release/LlamaVillage.app
```

The first build runs the `hook/build.dart` scene build (it imports
`assets/llama.glb` into `flutter_scene_generated/`) and fetches the
llama.cpp native runtime for llamadart.

Checks:

```
flutter analyze
flutter test          # pure-Dart sim tests on canned models
```

### Quitting

Cmd-Q and the window's close button both go through Flutter's exit
request, which stops the sim and disposes every model engine before the
process exits (ggml's Metal teardown crashes if the process exits with
models still loaded). Quitting while the models load waits for the load
and then frees them.

### Self-test

`tool/run_selftest.sh <capture_dir> [seconds]` runs the release build with
an autoplay script that takes screenshots (overview by day, a
conversation, Dash's options, the inspector, the storm, night), logs frame
rates split by whether the model was generating, and quits. The hooks
are inert unless their environment variables are set (`VILLAGE_CAPTURE`,
`VILLAGE_AUTOPLAY`, `VILLAGE_EXIT`, `VILLAGE_MS_PER_MINUTE`,
`VILLAGE_CANNED`, `VILLAGE_FPS`, `VILLAGE_QUIT_AFTER`,
`VILLAGE_CLOSE_AFTER`); see
`lib/self_test.dart`.

## Layout

- `lib/sim/` is the pure-Dart simulation, with no Flutter or llamadart
  imports: clock, places and path graph, cast, knowledge base, story
  threads, utility decisions, dialogue and outcomes, Dash, logs, and the
  model interfaces with canned stand-ins.
- `lib/ai/models.dart` backs the sim's model interfaces with llamadart.
- `lib/render/` builds the diorama, sky, llamas and Dash with
  flutter_scene.
- `lib/ui/` holds the bubbles, HUD, log, options and inspector.
- `lib/app.dart` wires it together: loading, input, the game loop and
  shutdown.
