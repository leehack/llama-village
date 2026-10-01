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

## Where the AI runs

Three local models do the writing and judging; plain code does the
rest. Latencies are typical medians (worst seen in brackets) for the
release build on an M4 Max, from the self-test's per-call metrics (the
`VILLAGE CALLS` log lines).

| Job | Model | Why a model | Output | Latency |
| --- | --- | --- | --- | --- |
| Dialogue lines | gemma-4-E2B | Each line comes from what that llama knows right now, its mood, its goals and the conversation so far, so the talk follows the knowledge state instead of a script | Free text, one line (48 tokens max) | 0.5-0.7 s per line (0.9 s) |
| Inner thoughts | gemma-4-E2B | A private thought from the llama's mood, activity, wants and what is on its mind | Free text, under 14 words | 0.7-1.1 s (1.5 s) |
| Dash's choices | gemma-4-E2B | The rules pick four intents (gossip and a kind word always, plus two of compliment, praise, tell, gift, help and tease) and the facts behind them; the model words each one for this llama | Grammar-constrained JSON, one string per intent (the keys stay English in every language); retried, then canned lines | 0.7-1.9 s, written while Dash flies over |
| The llama's reply to Dash | gemma-4-E2B | How the llama takes it (offended to delighted) is a rule; the model voices it | Free text | 0.3-0.7 s |
| Conversation outcomes | gemma-4-E2B | Reads the finished conversation and judges mood and friendship changes, which candidate facts were said out loud, and a thread's yes/no question (did Mo agree to sing?) | Grammar-constrained JSON: enums, booleans and fact ids | 1.7-1.9 s (2.0 s) |
| Memory check | EmbeddingGemma | Compares what the teller said with each fact the listener did not know, so a fact only counts as told when the words back it up | Embeddings, cached and kept in saves | 50-80 ms per batch |
| Morning plans | gemma-4-E2B | Each llama plans its day from what it knows and wants | Free text, `HH place \| activity` lines, parsed; a work-day plan if that fails | 1.4-2.8 s each, five per morning while the clock waits at 05:59 |
| Evening reflections (dreams) | gemma-4-E2B | One first-person sentence about the day, shown as the night's dream bubble and fed into the next morning's plan | Free text | about 0.6 s |
| Cutscene lines | gemma-4-E2B | Clover's festival announcement and each singer's song line | Free text | 0.25-0.5 s |
| Epilogue cards | gemma-4-E2B | One storybook-style sentence per llama from its final state and what it knows | Free text | about 0.35 s each |
| The storybook | gemma-4-E2B | One fairy-tale page per day and one for the ending, retold from that day's digest of what really happened | Free text, one paragraph of 80-120 words, streamed onto the page; a page written by rules if it fails | 1.6-2.2 s per page (3.1 s), 10-14 s for the book |
| Casual-topic choice | Laya (optional) | Picks what a llama brings up in small talk among the options the rules allow (never its own secret unless confessing, never news the listener told it); a topic tied to a strong goal is chosen by the rules | One choice among the options | about 0.1 s |

Which facts go into a prompt is a rule (`relevantFacts` scores goals,
recency, secrets and the listener); the embeddings only check what was
said. Every job whose output the player reads runs in the chosen language
(see Languages); plans, outcomes and topic choices stay English.

### What is not AI, and why

- **Movement and needs**: hunger, energy, company and what to do next are
  utility rules (`lib/sim/brain.dart`); the model-written morning plan is
  one of their inputs. The llamas never wait on a model to move.
- **Who knows what**: every fact, who knows it, how they learned it and
  whether they believe it is tracked in code (`lib/sim/facts.dart`). The
  outcome model can only claim that a fact was told; code accepts the
  claim only when the teller's words support it (keywords or embedding
  similarity), and a secret always needs its keywords. Prompts list only
  what that llama knows, so nobody repeats a secret they never heard.
- **Endings**: a fixed set of rules over the final state
  (`lib/sim/endings.dart`), so what the player did decides the ending.
- **The festival winner**: a score from each singer's skill, the
  audience's and Clover's feelings, the singer's mood and Clover's secret
  deal with Pip (`FestivalThread`).
- **Reactions to Dash**, who starts a conversation with whom, the story
  threads' events and the clock are rules too.

Rules keep the game fair (the player's choices, not a sampled token,
decide who wins and how the week ends), coherent (knowledge only moves
when it was really said) and testable (the endings, the festival and the
knowledge bookkeeping run in unit tests on canned models). Model output
that does not parse is retried once with another seed, then replaced by
a canned line, so play never depends on the model.

### On-device, offline and responsive

Everything runs on this Mac through llamadart on Metal, and the game
makes no network calls while it runs (llamadart's build hook fetches the
llama.cpp runtime when the app is built). The weights are 2.8 GB for
gemma-4-E2B (Q4_K_S), 318 MB for EmbeddingGemma 300M (Q8_0) and 402 MB
plus a 101 MB head for Laya (Q8_0). They are memory-mapped: during a game
the process holds about 4.6 GB resident, about 2 GB of it its own
footprint (Metal buffers, KV caches and the scene) and 3.6 GB the mapped
weight files.

The game never waits on a model:

- Each engine has a priority queue (Dash's reply first, then dialogue,
  outcomes, Dash's options and reflections, thoughts, and background work
  such as plans), and the world keeps ticking while it works.
- Dash's four options are written while he flies over, so they are
  usually ready on arrival.
- Conversations are generated one line at a time: each line appears as a
  bubble as soon as it is written, while the next one is being written
  ("…" marks a llama still thinking).
- Prompts go to the GPU in small micro-batches (128 tokens), so frames
  slip in between: about 45 fps while the model is generating against 59
  idle, under the default 60 fps cap.

## Features

- **Festival Week**: a five-day story with its own beat each day, a
  night cutscene between days, the Berry Festival on day 5 and one of
  three endings, followed by an epilogue card per llama and the results.
- **Generative llamas**: every line, plan, thought, evening reflection and
  epilogue is written live by a local model from what that llama knows.
- **Cutscenes**: the festival announcement, each night (sunset, hut
  lights going out, the moon, dream bubbles, a "Day N" card), the
  festival with a sung line per singer, and the ending.
- **Title screen, saves and gallery**: a drone flyover of the village
  behind the menu; an autosave every morning plus three manual slots;
  unlocked endings and each finished week's storybook are kept in the
  Endings gallery.
- **The storybook**: after the results, "Read the story" opens "The
  Week Dash Came to Berry Valley", a fairy tale of the week just played,
  a page per day, illustrated with pictures taken in the village.
- **Time-of-day lighting**: sunrise, midday, golden hour, blue hour and
  a moonlit night, a storm with rain, lightning and wet ground, and
  three graphics qualities.
- **A lived-in village**: grass, flowers, props, rippling water,
  fireflies and falling leaves, and cats, chickens, ducks, a dog and
  butterflies with lives of their own.
- **Sound**: synthesized music, ambience and effects, including the
  animals.
- **Accessibility**: text size, reduced motion and high-contrast bubbles.

## Festival Week

A game is five days. Clover announces the Berry Festival on the morning
of day 1; it is held on day 5 at 16:00 on the hilltop. In between: Pip's
scarf goes missing (day 1), June finds an unsigned poem (day 2), Mo bakes
a honey loaf (day 2), Bramble's storm arrives (day 3), Clover holds a
rehearsal (day 4) and strings up lanterns (day 5). A day runs from 06:00
to about 22:00, eight minutes at 1×.

The llamas walk the paths at their own pace (Pip quickest, Mo slowest,
about 1.5 m/s at 1×), so crossing the village takes up to an hour and a
half of game time and they set off early for the rehearsal and the
festival. They gallop only when they hurry: in the storm, or when walking
would make them late.

When every llama is asleep (or at 22:00) a night cutscene plays: the sun
sets, hut lights go out one by one, the moon crosses, each llama's evening
reflection appears as a dream bubble over its hut, then dawn and a "Day N"
card. The sim clock runs to 06:00 underneath (it waits for the llamas'
plans), and the game autosaves. Cutscenes letterbox the screen and pause
the sim; the animals carry on under the cutscene's sky (the chickens go
in and the cats curl up as the night skip's sun sets). Esc, Space or a
click skips a cutscene.

### Endings

How the week ends depends on what Dash did to the village, and there are
three endings to find:

- **Harmony Festival**: win the llamas over, set the record straight
  and bring them closer.
- **Drama Llama**: a little bird with a loose beak can stir up a lot.
- **Quiet Valley**: sometimes the valley is happiest left alone.

What counts: how well the llamas get on, whether false rumours are still
going round, how things stand between Pip and Mo, what became of
Bramble's secret, and how far the llamas trust Dash. The results screen
shows each of these after the epilogue. (The exact rules are in
`lib/sim/endings.dart`, if you want them spoiled.)

### The storybook

Once the ending scene starts, the dialogue model writes the week as a
picture book in the background: a cover, a page per day and a page for
the ending, each a gentle fairy-tale paragraph. Each page is grounded in
that day's digest: the sim keeps a journal of the week's notable moments
(world events, story-thread turns, conversations and how they ended,
secrets and rumours passed on, and Dash's visits and how they went), and
a page gets the day's seven weightiest moments, in order, with the
instruction to use nothing else. The digest is a pure function of the
journal, so the same week always gives the same digest. A page the model
fails to write is written from the same digest by rules.

The pictures are taken in the engine during play: a small capture of the
3D view (no HUD or bubbles) when a story moment happens with the llamas
involved on screen (a conversation, a rumour, the storm, a
confession, the scarf turning up), during the announcement, the
festival and the ending scenes, and one of the village each day. The
best two of each day travel inside the save, so a loaded game's
storybook still has them; a page without a picture shows the portrait
of the llama it names most (or the day's lead) over a painted valley.

The book opens on a spread (picture left, text right) with a drop cap,
page numbers and a page-turn animation; ← and →, the arrows or a click
on either page turn it, and Esc closes it. Pages still being written
stream in as the model writes them. Every finished book is kept in the
Endings gallery and can be read again.

Dash's levers: compliments, gifts and help build trust; a pleased llama
confides something Dash did not know; "tell" passes news on (corrections
first); "praise" makes the listener like another llama more; "gossip"
plants a lie that a trusting listener believes.

## Controls

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
- **Time**: Space pauses; the 1×/2×/4× buttons set the speed. One game
  minute is half a second at 1×; the clock waits at dawn while the llamas
  write the day's plans.
- **Esc** opens the pause menu: resume, save to one of three slots,
  settings, save and quit to the title (to the autosave slot), or quit.
  **Continue** on the title screen loads the newest save that loads.
- In a cutscene, **Esc**, **Space** or a click skips it.
- The **village log** (bottom left) lists events, conversations, who
  learned what, and story-thread turns.

Speech bubbles show "…" while the model is still writing a line; thought
bubbles (rounded, italic) show what an idle llama is thinking. Bubbles in
a crowd (and the dream and song bubbles in cutscenes) stack so they never
cover each other.

## Settings

The **gear** button (and the title and pause menus) opens Settings, in
five groups:

- **Language**: System default (the Mac's language when it is Korean or
  French, else English), English, 한국어 or Français; see Languages below.
- **Graphics**: a frame-rate cap of 30, 60 (default) or 120 fps (120
  only matters on a ProMotion display) and Graphics quality (Low, Medium
  or High, the default; see below). The cap skips scene renders between
  display refreshes; the sim and animations run on real time, so their
  speed does not change.
- **Audio**: music and sound-effect volumes (0.5 and 0.7 by default) and
  Mute all.
- **Gameplay**: text speed and the starting time speed.
- **Accessibility**: text size, reduced motion (shorter cutscene camera
  moves, no shake, a slower title flyover, calmer animals and half the
  fireflies and falling leaves) and high-contrast bubbles.

Settings are saved with shared_preferences.

## Languages

The game is in English, Korean and French. Every menu, the HUD, the
inspector's labels, hints, endings, the results, the storybook,
cutscene captions, credits and loading and error messages come from
Flutter gen-l10n (`lib/l10n/app_{en,ko,fr}.arb`; a test checks that the
three have the same keys and placeholders). Switching the language in
Settings takes effect at once, in the menus and in the game: the next
line any llama says is in the new language.

What the llamas say and write is generated in the chosen language:
dialogue, thoughts, evening reflections, Dash's options and the replies,
the epilogue cards, the cutscene lines and the storybook. The prompts
stay in English, since the sim's facts, goals and intents are English;
each one ends with a short instruction in the target language (with the
game's names for the Berry Festival, the Golden Bell and so on), and the
call runs under a system prompt that names the language. The names Pip,
Mo, June, Bramble, Clover and Dash are never translated; Korean output
that spells them in Hangul (피프, 브램블) gets them back in English
letters, with the particle fixed to match (Pip이, Mo가). Plans,
conversation outcomes and Laya's topic choice stay English, and Dash's
options are grammar-constrained JSON whose keys stay English, so they
parse in any language. Facts told in Korean or French are still
recognised as told: the facts' English keywords have Korean and French
equivalents (`keywordTranslations` in `lib/sim/lang.dart`).

The sim's own text is localised too. The sim keeps its sentences as
templates with their parameters (`Said` in `lib/sim/said.dart`), and the
UI says them through `say…` messages in the ARB files. This covers the
village log, the inspector's facts, goals and "why" notes, and the
storybook pages and epilogue lines written by rules. The sim's English
wording stays in the prompts, the transcript and its logic. The one
exception is a "why" note that quotes a morning plan: plans are written
in English, so in Korean and French the note names only the place.

An epilogue card is grounded in the same ending facts as the
storybook's last page: the ending that was decided, the festival winner
and how the village stands. A line that names a different winner, or a
llama fainting who did not, is written once more and then replaced by
the rule-made line.

Korean and French take more tokens than English, so each call gets a
larger budget and runs longer: on a quiet M4 Max, a dialogue line takes
about 0.26 s in English against 0.37 s in French and 0.44 s in Korean,
and a storybook page about 1.2 s against 1.9 s and 1.7 s.

Korean is set in three bundled faces (`assets/fonts/`, SIL Open Font
License 1.1): Gowun Dodum for the menus, HUD, inspector, log and
settings; Jua for titles, headings, speech and thought bubbles and
Dash's options; and Gowun Batang (Regular and Bold) for the storybook's
text, titles and drop cap. They apply when the language is Korean, or to
a line with Hangul in it, so a mixed line such as "Pip이" is set in one
face; English and French keep the system faces, with the Korean ones as
fallbacks. The files are subsets (Latin, punctuation, jamo, CJK symbols,
fullwidth forms and the 2,350 common Hangul syllables of KS X 1001, 6 MB
for the four), so a rarer syllable falls back to Apple SD Gothic Neo or
AppleMyungjo.

## The look and the village's animals

The light follows the clock: a clear pink sunrise, a bright midday, a warm golden hour, a blue hour as the lamps come on and
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

## Credits

The game's Credits page lists these too.

- Models: Gemma 4 E2B and EmbeddingGemma 300M by Google DeepMind (Gemma
  4 licence, Apache License 2.0, and the Gemma Terms of Use), and the
  optional Laya decision model.
- [llamadart](https://pub.dev/packages/llamadart) (MIT, © 2024 Jhin Lee)
  with llama.cpp (MIT, © the ggml authors);
  [flutter_scene](https://pub.dev/packages/flutter_scene) (MIT, © 2023
  Brandon DeRosier); [flutter_soloud](https://pub.dev/packages/flutter_soloud)
  (MIT, © 2024 the flutter_soloud authors) with SoLoud (zlib/libpng, ©
  Jari Komppa); Flutter, shared_preferences, path_provider and intl (BSD
  3-Clause, © the Flutter authors).
- Fonts, all under the SIL Open Font License 1.1 (each `OFL.txt` sits
  next to its font in `assets/fonts/`):
  [Gowun Dodum](https://github.com/yangheeryu/Gowun-Dodum) (© 2021 The
  Gowun Dodum Project Authors), Jua (© 2018 The Jua Project Authors) and
  [Gowun Batang](https://github.com/yangheeryu/Gowun-Batang) (© 2021 The
  Gowun Batang Project Authors), from
  [google/fonts](https://github.com/google/fonts); subset with
  fontTools, names unchanged (none declares a Reserved Font Name).
- Music and sounds are synthesized in code (`tool/audio/gen_audio.py`).

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

The first build runs the `hook/build.dart` scene build (it imports the
character models in `assets/` into `flutter_scene_generated/`) and fetches
the llama.cpp native runtime for llamadart. The models and the inspector
portraits are generated by the Blender scripts in `tool/blender/` (see its
README).

Checks (CI runs the same on every push and pull request, see
`.github/workflows/ci.yml`):

```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test          # sim, UI and settings tests on canned models; no GPU or model files
```

### Saves

Saves are JSON files in `~/Library/Application Support/<bundle id>/saves`:
`autosave.json`, `slot1.json` to `slot3.json`, `endings.json` (the
gallery) and one file per storybook in `storybooks/`. A save holds the
whole sim (needs, places, plans, memories and the embedding cache, the
knowledge base, threads, Dash, the clock, the RNG state, and the
storybook's journal and pictures) under a version number; conversations
in flight are not saved. A save from before the storybook loads with an
empty journal, and its storybook pages fall back accordingly.
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
skip (later ones are skipped), the inspector, the festival, the ending,
the epilogue, the results, the storybook (the cover, a page turning, two
pages and the ending) and the gallery again, with a PNG at each stop.
Pair it with
`VILLAGE_BOT=harmony|drama|quiet` (the bot plays Dash toward that
ending), `VILLAGE_LANG=en|ko|fr` (the language for the run, without
touching the saved settings), `VILLAGE_TIME_SCALE=32` (a compressed week) and
`VILLAGE_SAVE_DIR=<dir>` (keeps saves and the gallery out of your
profile); `VILLAGE_JUMP_DAY=5` starts a new game on that morning.
`VILLAGE_QUIT_AT=menu|cutscene|generation|story` quits at that moment
(`story`: while the storybook is being written), through the title
screen's Quit button or the system exit request.

```
tool/run_selftest.sh /tmp/week 400 VILLAGE_AUTOPLAY=week VILLAGE_CANNED=1 \
  VILLAGE_BOT=drama VILLAGE_TIME_SCALE=32 VILLAGE_MS_PER_MINUTE=500 VILLAGE_SAVE_DIR=/tmp/week_saves
```

For a memory soak, `VILLAGE_MEMLOG=10` logs a `VILLAGE MEM` line every
10 s: the resident set size, the villages still alive, and the size of
every collection a long session could grow (the journal, the storybook
pictures and their bytes, the gallery, diaries and thoughts, facts,
conversations, lines, the log, events, model call records, the
embedding cache, bubbles, scene nodes, Flutter's image cache, audio
voices and whether the models are loaded); see `lib/game/mem_probe.dart`.
`VILLAGE_REPLAY=90` makes the week script then play two more games of
90 s each, each left through "Save and quit to menu", to check that
memory returns to its baseline on the title screen. A locked screen or a
sleeping display sends no vsync, which stops the game; for an unattended
run, `VILLAGE_KEEP_TICKING=1` steps the game and pumps frames itself
meanwhile.

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
- `lib/l10n/` holds the English, Korean and French strings (ARB) and the
  generated localizations; `lib/ui/strings.dart` says the sim's names and
  labels in the player's language.
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
