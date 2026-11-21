# Otter & Mosey: Prehistoric Times

A native iOS and iPadOS game for UK children aged about 7–9 that teaches times tables and the
matching division facts. Otter and Mosey take a time machine back to the dinosaurs, crash, and have
to win back six machine parts from ever fiercer dinosaurs, finishing with the T-Rex.

Landscape only. iOS / iPadOS 26 or later. Fully offline: no accounts, adverts, purchases or
network calls. A web version follows once the iOS game is finished.

**The game design and milestones are in [docs/PLAN.md](docs/PLAN.md).**

## Status

**M0 to M4 are done: all six zones and the finale can be played from start to finish.** Rewards,
grown-ups' extras and polish (M5 to M7) come next. See [docs/PLAN.md](docs/PLAN.md).

What plays today:

- **The opening:** on Rainbow Island Otter shows off the Tick-Tock Times Machine; three easy questions
  wind it up; a flash back 66 million years; it crash-lands in Hatchling Hollow, the six parts fly
  off, and a T-Rex roars somewhere not far enough away.
- **Crash Camp map:** the wrecked machine in the middle with a slot for each part, and the six zones
  ringed around it, each with a Roar Rating. Tap the camp to visit it or the museum.
- **Hatchling Hollow** (Mama Maia, Roar Rating 1), five levels:
  Egg Hatch (answers hatch baby dinosaurs), Dino Dash (run from Mama Maia: the right path is a burst
  of speed, a wrong one lets her gain; a catch is just a sniff), Stepping Stones (stones rise out
  of a stream), Tiptoe Past (sneak up on her while she sleeps on the Cog) and the Big Escape (she
  chases, roaring, then turns out to be a friend and hands back the Cog).
- **Fix-It Workshop:** after the Big Escape, two bolt arrays built a row at a time (counting in the
  zone's table) and a division to finish; then the part clicks onto the machine.
- **Fossil Museum:** a skeleton for each times table, a bone for each fact once it is secure, gold
  when fluent.
- **The times-tables engine (M1):** every fact from 1 × 1 to 12 × 12 tracked on its own, zones
  sharing out the grown-up's tables, at most three new facts a level, missed facts coming back,
  picking answers while a fact is new and typing once it is getting there. See
  `PrehistoricTimesCore/Education`.
- **Campfire Sing-Along:** Otter and Mosey chant a times table over a campfire beat, three rounds
  that get faster and leave more for the child to sing, then "Fill the ladder" (the table typed in
  order) and an optional shuffle challenge. Every level opens with about a minute of its table's
  song, moving on level by level (each round in turn, then the ladder, then a mix). Each song has
  its own baby dinosaur musician to meet, who sparkles and then wins a crown as the song is sung
  again. Baby dinosaurs
  and friends join in, one per line sung and per right answer. A record for each table on the song
  shelf (reached from the campfire band at Crash Camp or the map's camp card), and grown-up
  settings for rounds, speed-up and level songs. See section 14 of the plan.
- **Music:** a prehistoric main theme, a jungle tune for Hatchling Hollow and a bouncy chase.
- **Grown-ups:** year-group presets, tables 1 to 12 with focus stars, multipliers, question kinds,
  answer style and chase pace (Calm, Exciting or Gentle dinosaurs).

Debug launch arguments also include `-debugRoute museum|workshop` and `-debugSkipIntro` (go straight
to a level's first question).

## Build and run

Requirements: macOS with Xcode 26 or later. No third-party dependencies.

```bash
open PrehistoricTimes.xcodeproj
```

Choose the `PrehistoricTimes` scheme and an iPhone or iPad simulator, then Run. From the command line:

```bash
xcodebuild -project PrehistoricTimes.xcodeproj -scheme PrehistoricTimes -destination 'platform=iOS Simulator,name=iPad (A16)' build
```

If several simulators share a name, pass `id=<UDID>` from `xcrun simctl list devices` instead.
Bundle ID: `otter-and-mosey-t-rex-times-trouble.dev.skynolimit`. Home-screen name: "Prehistoric Times".

## Tests

```bash
cd Packages/PrehistoricTimesCore && swift test
```

The core tests cover question correctness, adaptive difficulty, spaced repetition, sessions,
progression, trophies and save files. They run on macOS in under a second.

```bash
./tools/playtest
```

The regression runner: core tests, then app integration and UI play-through tests on fresh
temporary iPhone and iPad simulators, which it deletes afterwards. `--only core|simulator` reruns a
single layer and `--full` plays all 30 levels. Reports go to `playtest-results/<timestamp>/`. The
browser layers switch themselves on once a `web/` version exists.

## Project layout

| Path | What it holds |
| --- | --- |
| `Packages/PrehistoricTimesCore` | Platform-neutral logic (Foundation only): questions, generators, learner model, sessions, progression, trophies, save data and the JSON content. |
| `PrehistoricTimes/App` | App entry, navigation and the app model. |
| `PrehistoricTimes/Game` | SpriteKit: scenes, characters, effects, art loading. |
| `PrehistoricTimes/UI` | SwiftUI: menus, HUD, keyboards, dialogue, grown-ups' area. |
| `PrehistoricTimes/Audio` | Audio, narration and haptics. |
| `PrehistoricTimes/Assets.xcassets`, `PrehistoricTimes/Resources` | Bundled art, sound and recorded speech. |
| `tools/` | Development-time content, art and audio pipelines. |
| `docs/PLAN.md` | The game plan and milestones. |

## Content, art and audio pipelines

These are unchanged from Lost Islands; see its README and `docs/ELEVENLABS.md` for the full detail.

- **Content:** edit `tools/content/islands.py`, then run `python3 tools/build_content.py` to
  regenerate the JSON in `Packages/PrehistoricTimesCore/Sources/PrehistoricTimesCore/Resources`.
- **Art:** `python3 tools/generate_art.py` (OpenAI Images API, reads
  `OPENAI_API_KEY_CHATGPT_GRAPHICS`, tracks spend in `tools/.art-ledger.json`), then
  `python3 tools/import_art.py`. `tools/raw/otter_ref.png` and `tools/raw/mosey_ref.png` are the
  character references for new poses; `tools/raw` and `tools/reference` are git-ignored.
  `tools/art_manifest.json` lists only this game's own assets (plus the two references, which are
  skipped because they exist). The Lost Islands images are already in the asset catalogue and their
  prompts stay in the Lost Islands repository, so the generator never regenerates them.
- **Sound, voices and music:** ElevenLabs, via the scripts in `tools/sfx`. They read
  `ELEVENLABS_API_KEY` from the git-ignored `.env.local` at the repository root (copied from Lost
  Islands). New voices are designed with `node --env-file=../../.env.local design-voices.mjs maia trevor`
  and kept with `--keep <who> <n>`; previews land in the git-ignored `tools/sfx/samples`. The Otter, Mosey and
  narrator voices in `tools/sfx/narration.config.json` are the same ones Lost Islands uses; their
  names in the ElevenLabs account still say "Lost Islands", which is correct.

Nothing in the app talks to the network, and no key is ever bundled.

## Debug launch arguments (Debug builds only)

| Argument | Effect |
| --- | --- |
| `-debugLevel bay-1` | Open a level directly. |
| `-debugRoute map` | Open a screen: `map`, `collection`, `home`, `parent` (skips the grown-ups' gate), `ending`, `intro`, `island:woods`, `shelf` (the song shelf), `song:3` (the 3s song), `levelsong:hollow-1` (a level's opening song). |
| `-debugPlaytest bay-1` | Play-test a level as if started from the grown-ups' area (nothing is saved). |
| `-debugUnlock` | Treat every level as cleared for this launch. |
| `-debugShort` | Limit levels to three questions, and sing-along songs to three lines. |
| `-debugCrowd 30` | Start a sing-along with 30 friends already singing. |
| `-debugQuiz` | With `-debugRoute song:3`, go straight to filling the ladder. |
| `-debugBefriend` | In a Big Escape, skip the chase and go straight to the boss making friends. |
| `-debugTour` | Open the map with a hammer menu for every level, every zone’s Fix-It Workshop, songs, camp, collection, trophies, museum, opening story and ending. Includes answer cues. |
| `-debugAnswers` | Show the exact choice or digits in every level, sing-along quiz and workshop. Combine with a direct route for a layout check without the hammer menu. |
| `-debugResults` | Open a level directly on its perfect-run rewards screen. |

**On Mike’s iPhone**, run `./tools/iphone-playtest -debugShort` from this game’s directory. It builds the current Debug sources, installs the app, and starts the tour. Use the hammer at the left edge to change activities mid-session. The tour and answer-cue switches start with a fresh in-memory player on each launch. Add `-debugUnlock` to explore cleared-game rewards and collections. Set `PLAYTEST_DEVICE` to target a different device by name or UDID.

| To check | Arguments to add to `./tools/iphone-playtest` |
| --- | --- |
| Short level, including normal gestures, mistakes and hints | `-debugLevel hollow-1 -debugSkipIntro -debugShort` |
| Boss friendship and part collection | `-debugLevel hollow-5 -debugSkipIntro -debugBefriend` |
| Trophy collection and reward navigation | `-debugLevel hollow-1 -debugResults` |
| Song ladder, shuffled questions and song reward | `-debugRoute song:3 -debugQuiz -debugShort` |
| Populated camp and trophy cabinet | `-debugUnlock -debugRoute home` |
