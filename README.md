# Llama Village

A small 3D village of AI llamas that live their own lives while you watch
and meddle as Dash, a little blue bird, over one Festival Week.

Five llamas (Pip, Mo, June, Bramble and Clover) each have a persona, needs,
friendships, goals and secrets. They plan their day, walk the paths
between their huts, the pond, the berry bushes, the bakery and the
hilltop, and stop to talk. What they say is written live by an on-device
language model, one line at a time, and only from what each llama
actually knows. Facts move between them by being seen, told, overheard or
announced, so rumours spread, secrets slip out, and story threads (a lost
red scarf, the Berry Festival singing contest, a secret crush, a bread
rumour and a storm warning) play out differently every run.

## Festival Week

A game is five days. Clover announces the Berry Festival on the morning
of day 1; it is held on day 5 at 16:00 on the hilltop. In between: Pip's
scarf goes missing (day 1), June finds an unsigned poem (day 2), Mo bakes
a honey loaf (day 2), Bramble's storm arrives (day 3), Clover holds a
rehearsal (day 4) and strings up lanterns (day 5). A day runs from 06:00
to about 22:00, eight minutes at 1×.

When every llama is asleep (or at 22:00) a night cutscene plays: the sun
sets, hut lights go out one by one, the moon crosses, each llama's evening
reflection appears as a dream bubble over its hut, then dawn and a "Day N"
card. The sim clock runs to 06:00 underneath (it waits for the llamas'
plans), and the game autosaves. Cutscenes (night, the announcement, the
festival, the ending) letterbox the screen and pause the sim; Esc, Space
or a click skips one.

After the festival comes an ending scene, an epilogue card per llama
(written by the model from its final state; a rule-made line if that
fails) and the results. What Dash changed is read off the sim:

- **harmony**: the mean friendship among the five llamas (-10 to 10);
- **truth**: false facts still believed (the bread rumour, Dash's lies);
- **Pip and Mo**: made up (both 3+, scarf back, rumour dropped), fell out
  (either at -3 or lower) or left unsaid;
- **Bramble's poems**: still secret, out in the open, confessed and
  accepted or declined, or exposed by gossip and declined;
- **trust in Dash**: each llama's friendship toward Dash.

The ending rules, in order (`lib/sim/endings.dart`):

1. **Drama Llama**: four or more false beliefs, or two or more of: harmony
   below 0.5, a Pip-Mo rift, Bramble exposed and declined, no festival
   winner.
2. **Harmony Festival**: a festival winner, no false belief left, harmony
   1.5 or more, mean trust in Dash 1.5 or more, and no Pip-Mo rift.
3. **Quiet Valley** otherwise.

Dash's levers: compliments, gifts and help build trust; a pleased llama
confides something Dash did not know (corrections first); "tell" passes
news on (a correction to someone who believes the rumour comes first);
"praise" makes the listener like another llama more; "gossip" plants a
lie that a trusting listener believes. Unlocked endings are kept in the
Endings gallery on the title screen.

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
- **Click the ground** or hold **WASD** (or the arrow keys) to fly Dash
  around. Dash witnesses what happens where it hovers, and can pass true
  news on.
- **Camera**: drag to orbit, right-drag or two-finger drag to pan, scroll
  or pinch to zoom, Q/E to turn. **F** follows the selected llama (or
  Dash), **O** returns to the overview.
- **Esc** opens the pause menu: resume, save to one of three slots,
  settings, save and quit to the title (to the autosave slot), or quit.
  **Continue** on the title screen loads the newest save that loads.
- **Time**: Space pauses; the 1×/2×/4× buttons set the speed. One game
  minute is half a second at 1×; the deep night runs faster, and the
  clock waits at dawn while the llamas write the day's plans.
- The **village log** (bottom left) lists events, conversations, who
  learned what, and story-thread turns.
- The **gear** button (and the title and pause menus) opens Settings,
  in four groups:
  - **Graphics**: a frame-rate cap of 30, 60 (default) or 120 fps (120
    only matters on a ProMotion display) and Graphics quality (Low,
    Medium or High, the default; see below). The cap skips scene renders
    between display refreshes; the sim and animations run on real time,
    so their speed does not change.
  - **Audio**: music and sound-effect volumes (0.5 and 0.7 by default)
    and Mute all.
  - **Gameplay**: text speed and the starting time speed.
  - **Accessibility**: text size, reduced motion (shorter cutscene
    camera moves, no shake, a slower title flyover, calmer animals and
    fewer particles) and high-contrast bubbles.

  Settings are saved with shared_preferences.

Speech bubbles show "…" while the model is still writing a line; thought
bubbles (rounded, italic) show what an idle llama is thinking.

## The look and the village's animals

The light follows the clock: a pink sunrise with a little morning haze,
a clear midday, a warm golden hour, a blue hour as the lamps come on and
a moonlit night with glowing windows and fireflies. The storm darkens
the sky, thickens the fog, flashes lightning now and then and leaves the
ground glossy with puddles that dry over the next game hour. Clouds
drift over, leaves fall from the round trees, the pond's ripples
shimmer, and there are grass tufts, wildflowers, fences, a well, a
chicken coop, a doghouse, laundry lines, a vegetable patch, a dock with
a rowing boat and lanterns along the paths.

Animals live around the llamas without talking: two cats wander, sit,
groom, nap in sunny spots, climb onto hut roofs, chase butterflies and
run from Dash when he swoops low; five chickens peck around the bakery
and the berry bushes, flutter away from walking llamas and go into the
coop at dusk; three ducks paddle and dabble on the pond and tuck in by
the reeds at night; and a dog tags along after Dash for a while, then
gets bored and goes home. Everyone hides in a storm, and the cats and
the dog sleep at night. They meow, cluck, quack and woof now and then,
quieter with distance and scaled by the effects volume.

Graphics quality: High has everything (ground-truth ambient occlusion,
bloom, soft and contact shadows, god rays at sunrise, all the grass,
flowers and particles); Medium drops god rays and contact and soft
shadows and thins the foliage and particles; Low also drops ambient
occlusion, bloom and the animals' shadows and uses a smaller shadow
map.

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

The models load in the background behind the title screen. If a required
model is missing, the title screen says which file and where it looked,
and new games play with canned lines instead.

Actions, reactions and knowledge bookkeeping are rules; the model writes
the words. When the model's output does not parse, the sim retries once
with another seed and then falls back to a canned line, so the world never
waits on the model.

## Sound

Music and effects are synthesized by `tool/audio/gen_audio.py` (additive
synthesis, shaped noise and an FFT reverb; nothing is sampled or
downloaded) and committed as Ogg Opus files in `assets/audio/`. A cozy
day loop and a softer night loop crossfade with the time of day, and a
rain loop fades in with the storm. Effects: Dash's wing flaps and arrival
chirp, footsteps of nearby walking llamas, a murmur as each speech bubble
appears (pitched per llama), a bubble pop, a UI click, a sparkle when a
fact Dash spread is learned, birds by day and crickets at night, and
the animals' meows, clucks, quacks and woofs.

Playback uses [flutter_soloud](https://pub.dev/packages/flutter_soloud)
(pinned to 4.1.7, the newest release compatible with flutter_scene
0.23.0's `code_assets` constraint): a native SoLoud mixer with low-latency
one-shots, per-voice speed and pan, and sample-exact loops from clips
decoded into memory. The engine shuts down before the models are freed on
quit.

To regenerate (needs numpy and ffmpeg with libopus):

```
python3 tool/audio/gen_audio.py [--preview /tmp/village_audio.m4a] [--only meow,cluck]
```

Loop lengths are whole Opus frames minus the encoder pre-skip, so they
decode sample-exact.

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

### Saves

Saves are JSON files in `~/Library/Application Support/<bundle id>/saves`:
`autosave.json`, `slot1.json` to `slot3.json` and `endings.json` (the
gallery). A save holds the whole sim (needs, places, plans, memories and
the embedding cache, the knowledge base, threads, Dash, the clock and the
RNG state) under a version number; conversations in flight are not saved.
A damaged or other-version save is listed as damaged and never loaded.

### Quitting

Cmd-Q, the window's close button and the Quit buttons all stop the sim
and dispose every model engine before the process exits (ggml's Metal
teardown crashes if the process exits with models still loaded).
Quitting while the models load waits for the load and then frees them.
Leaving a game for the title screen cancels its model work and waits for
it to stop before another game can use the engines.

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

`VILLAGE_AUTOPLAY=week` runs the Festival Week script instead
(`lib/game/week_autoplay.dart`): the title screen, gallery, credits and
settings, a new game, the pause menu and a manual save, the first night
skip (later ones are skipped), the festival, the ending, the epilogue,
the results and the gallery again, with a PNG at each stop. Pair it with
`VILLAGE_BOT=harmony|drama|quiet` (the bot plays Dash toward that
ending), `VILLAGE_TIME_SCALE=32` (a compressed week) and
`VILLAGE_SAVE_DIR=<dir>` (keeps saves and the gallery out of your
profile); `VILLAGE_JUMP_DAY=5` starts a new game on that morning.
`VILLAGE_QUIT_AT=menu|cutscene|generation` quits at that moment, through
the title screen's Quit button or the system exit request.

```
tool/run_selftest.sh /tmp/week 400 VILLAGE_AUTOPLAY=week VILLAGE_CANNED=1 \
  VILLAGE_BOT=drama VILLAGE_TIME_SCALE=32 VILLAGE_MS_PER_MINUTE=500 VILLAGE_SAVE_DIR=/tmp/week_saves
```

`VILLAGE_TOUR=shots` (with `VILLAGE_CAPTURE=1`) starts a new game and
follows one day without the week's cutscenes, capturing the looks and
the animals (sunrise, midday, the storm, the golden and blue hours,
night with fireflies, chickens, ducks, cats on a roof and a crowd of
bubbles); the storm comes on day 3, so add `VILLAGE_JUMP_DAY=3` to catch
it. `VILLAGE_TOUR=perf` (best with `VILLAGE_MS_PER_MINUTE=100`) logs the
frame rate per graphics quality for the sunrise, a morning, the golden
hour and the storm, with the model generating and idle. See
`lib/render_tour.dart`.

## Layout

- `lib/sim/` is the pure-Dart simulation, with no Flutter or llamadart
  imports: clock, places and path graph, cast, knowledge base, story
  threads, utility decisions, dialogue and outcomes, Dash, logs, and the
  model interfaces with canned stand-ins.
- `lib/ai/models.dart` backs the sim's model interfaces with llamadart.
- `lib/render/` builds the diorama, sky, scene dressing, water,
  particles, llamas, animals and Dash with flutter_scene.
- `lib/ambient/` is the pure-Dart life of the animals: their state
  machines, the village layout they use, and when they make sounds.
- `lib/ui/` holds the bubbles, HUD, log, options, inspector and settings;
  `lib/ui/menus/` the title screen, pause menu, credits, gallery,
  epilogue and results.
- `lib/cutscene/` is the timeline runner (camera keys, letterbox, fades,
  text, cues, holds, shake), the scene scripts and their overlay.
- `lib/game/` directs the week (`director.dart`), stores saves and the
  gallery, and holds the player bot and the week autoplay.
- `lib/audio/` maps sim events to music and effects (`soundscape.dart`)
  and plays them with flutter_soloud.
- `lib/app.dart` wires it together: loading, the title screen, input,
  the game loop, saves and shutdown.
