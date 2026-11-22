# Otter & Mosey: Prehistoric Times — game plan

Status: **iOS game built (M0 to M7, 22 November 2026; see M7 for two loose ends).** The web version (M8) is next. The design
decisions are confirmed (section 13); smaller open questions are collected at the end.

A native iOS and iPadOS game for UK children aged about 7–9 that teaches **times tables and the
matching division facts**. Every question in the game is a times-tables question; the adventure is
the wrapper. Landscape only, iOS / iPadOS 26+, fully offline, no accounts, adverts or purchases.
A web version follows once the iOS game is finished.

---

## 1. The pitch

Otter has built a time machine out of a bathtub, an alarm clock and a cuckoo clock. It is called
the **Tick-Tock Times Machine**, because it runs on times tables. Mosey wants to see where he comes
from: mosasaurs swam the seas at the same time T-Rex walked the land, 66 million years ago. They
set the dials, whoosh back in time… and crash. The machine bursts into six parts that fly off
across the valley. Somewhere close by, something very big **ROARS**.

To get home they have to win back each part from a different dinosaur, starting with the gentle
ones and finishing with the fiercest of all: **the T-Rex**. Each dinosaur turns out to have a
funny reason for being cross, and the friends escape first and make peace afterwards, so the game
is exciting without ever being frightening.

Running jokes: Mosey keeps telling everyone he is *not* a dinosaur ("I'm a mosasaur!"), and so do
the pteranodons ("We're pterosaurs, actually!"). Otter is still always hungry.

### Tone rules

- Dinosaurs are fierce in a cartoon way: big roars, stomps, chases. Nobody is ever hurt or eaten.
- When a dinosaur catches up, something silly happens (it sneezes, sniffs Otter's sandwich, licks
  Mosey) and the chase carries on. **A level can never be failed.**
- Every boss ends with the misunderstanding cleared up and a new friend made (Lost Islands style).
- A grown-up setting, **Gentle dinosaurs**, softens roars, removes screen shake and slows chasers
  for sensitive children.

### Story beats

| Beat | What happens |
| --- | --- |
| Opening (Rainbow Island) | Reuses the Lost Islands title beach and music. Otter shows off the machine (powered by a leftover sliver of the Rainbow Crystal, reusing `crystal_shard`). One-question tutorial: wind the clock with an easy fact. |
| The crash | Time-travel whoosh, sputter, CRASH. Six parts fly off. A distant roar. Mosey: "That was a T-Rex." Otter: "How do you know?" Mosey: "Because it's a lot closer now." Run! |
| Each zone | Four escape levels, then a **Big Escape** from the zone's boss dinosaur, who has the machine part. |
| Back at Crash Camp | A short calm **Fix-It Workshop**: fit the part using arrays and fact families. The machine visibly rebuilds, piece by piece, on the map. |
| Finale | The T-Rex chases them through its territory. The twist: the last part, the **Times Core**, landed on his back, its ticking itches, and his tiny arms can't reach it. Otter climbs up, unhooks it and gives him the scratch of his life. Everyone gathers for a group photo (reuses the Lost Islands finale and group-photo screens), then the friends whoosh home. |

---

## 2. Zones and dinosaurs: easy to fierce

Six zones, each with a **Roar Rating** shown on the map as footprints (1–5, then "MAX"). The
dinosaurs get bigger, louder and faster, and the music more urgent, as the rating climbs.

| # | Zone | Boss dinosaur (Roar Rating) | Part they have, and why they're cross | Default tables (Year 3) |
| --- | --- | --- | --- | --- |
| 1 | **Hatchling Hollow** | Mama Maia the Maiasaura (1): a fussy mum, not fierce at all | The **Cog**. She's sitting on it, convinced it's one of her eggs. | ×2, ×5, ×10 (warm-up from Year 2) |
| 2 | **Three-Horn Meadow** | Trevor the Triceratops (2): grumpy, snorts and charges | The **Spring**, stuck on his middle horn. Three horns for the 3s. | ×3 |
| 3 | **Spiky Swamp** | Steggy the Stegosaurus (3): swings a spiked tail | The **Propeller**, spinning on one of her four tail spikes. Four spikes for the 4s. Mosey gets to swim. | ×4 ("double the 2s") |
| 4 | **Pterodactyl Peaks** | The Swoop Squad, a pteranodon flock (4): dive-bombing thieves | The shiny **Bell**, now in their nest. | ×8 ("double, double, double") |
| 5 | **Raptor Ridge** | The Snatch Pack, velociraptors (5): fast, clever, feathery ("They're like angry chickens!") | The **Dial**. They're playing keep-away with it. | ÷ facts for 3, 4 and 8, plus mixed review |
| 6 | **T-Rex Territory** | Rex the Tyrannosaurus (MAX) | The **Times Core** (see the finale). | Everything chosen, mixed |

Spinosaurus, Ankylosaurus, Parasaurolophus, Brachiosaurus and baby dinosaurs appear as background
characters, minor chasers and pets.

**When a grown-up changes the tables**, zones keep their story but their table focus is
recalculated: the chosen tables are put in a sensible difficulty order (10, 2, 5, 11, 3, 4, 9, 6,
8, 12, 7), shared across zones 1–5, and zone 6 mixes everything. If only one table is chosen, every
zone uses it, moving from plain facts to missing numbers, division and word problems.

### Levels

- Each zone: **4 levels + 1 Big Escape = 5 starred levels**, so **30 levels** in total (the same
  size as Lost Islands). Confirmed.
- After each Big Escape: an unstarred **Fix-It Workshop** interlude (3–4 calm puzzles).
- About **10 questions a level** (boss: 9, in three phases of 3) so a level takes 3–5 minutes.

---

## 3. Learning design

### Default: UK Year 3

The national curriculum asks Year 3 to *recall and use multiplication and division facts for the 3,
4 and 8 times tables*, building on 2, 5 and 10 from Year 2. Default settings:

- **Focus tables:** ×3, ×4, ×8. **Review tables:** ×2, ×5, ×10.
- **Multiply by:** 1 to 12.
- **Question types:** multiplication, missing number, division, counting in multiples, word problems.

Year 4 children sit the **Multiplication Tables Check** (25 questions, 6 seconds each, tables 2–12),
so the grown-ups' area offers a Year 4 preset and an MTC practice mode (section 6).

### Every fact is tracked on its own

The engine tracks each fact (for example `mul:8x7`, `div:8x7`), reusing the Lost Islands keys and
spaced-repetition boxes, and adds response times. Each fact moves through:

| State | Meaning |
| --- | --- |
| New | Not seen yet. |
| Learning | Seen; missed recently or answered with a hint. |
| Getting there | Right first time a few times. |
| **Secure** | Right first time 3 times, across at least 2 days. |
| **Fluent** | Secure, and usually typed (not picked) in under 4 seconds. |

### Choosing questions in a level

- About 60% from the zone's focus table (new and learning facts), about 25% facts due for spaced
  review from any chosen table, about 15% secure facts to keep confidence up.
- New facts arrive a few at a time (about 3 per level), easiest anchors first (×1, ×2, ×10, ×5),
  the hardest later (6×7, 7×8, 8×8 …).
- A missed fact comes back 2–3 questions later in the same level, then returns on the spaced
  schedule (3, 8, 20, 45, 100 answers, as in Lost Islands).
- Never the same fact twice in a row.

### Question types

| Type | Example | Notes |
| --- | --- | --- |
| Multiply | 4 × 8 = ? | The core of the game. |
| Missing number | 4 × ? = 32 | Links multiplication to division. |
| Divide | 32 ÷ 4 = ? | Year 3 expects division facts for 3, 4, 8. |
| Count in multiples | 8, 16, 24, ?, 40 | Stepping Stones mode. |
| Groups and arrays | "3 nests with 4 eggs each" (picture) | Fix-It Workshop, and hints. |
| Dinosaur word problems | "A Stegosaurus has 4 tail spikes. How many on 6 Stegosauruses?" | A fixed, recorded set, so every one is read aloud by the narrator. |
| Fact families | 3 × 4, 4 × 3, 12 ÷ 3, 12 ÷ 4 | Fix-It Workshop. |

### Picking versus typing the answer

Typing an answer (recall) builds memory far better than picking one (recognition), so:

- **New and learning facts:** pick from 3 answers.
- **Getting there and beyond:** type it on the game's number pad.
- Distractors come from real mistakes: the next or previous multiple, a neighbouring table, digits
  swapped (24 and 42), and adding instead of multiplying (3 + 4 = 7).
- A grown-up can set "always type" or "always pick".

### Hints and mistakes

- **Hint button** shows a strategy, never the answer: dinosaur footprints skip-counting along a
  number line, an array of eggs, the doubling chain (×2 → ×4 → ×8), a known fact to start from
  ("10 × 4 is 40, so 9 × 4 is 4 less"), or the swap ("You know 4 × 3!").
- **First miss:** gentle sound, try again. **Second miss:** the answer appears with a picture,
  Mosey explains it, and the fact comes back soon. Four recorded "ask a grown-up" lines from Lost
  Islands are reused when a child keeps struggling.
- **Speed is measured quietly, never demanded** by default. Stars come from accuracy only
  (85% for 3 stars, 55% for 2, finishing always earns 1).

---

## 4. Game modes

All built on the Lost Islands scenes, so the hard parts (layout, number pad, effects, HUD, hints,
narration) already exist.

| Mode | How it plays | Answer | Built from |
| --- | --- | --- | --- |
| **Dino Dash** | Otter rides Mosey (`duo_ride`) with a dinosaur behind them. Three paths ahead carry answers; take the right one for a speed boost. A gap meter shows how far ahead you are. | Pick | Maths Splash |
| **Tiptoe Past** | Sneak past a sleeping dinosaur. Each right answer is one tiptoe step; a wrong one makes it snore louder and open one eye. Comic tension, no clock. | Type | Number Rescue |
| **Egg Hatch** | Eggs show facts; answer to hatch babies, which become pets. | Type | Dragon Egg Rescue (reuses `egg`, `crack`, `chirp`) |
| **Stepping Stones** | Cross a river or lava by stepping on the next multiple; a wrong stone wobbles and sinks and they hop back. | Tap / drag | Rainbow Bridge |
| **Sky Snatch** | Pteranodons fly past carrying number stones; tap every one in the 8 times table, or the answer to the question shown. Missed ones loop back. | Tap | Word Blaster's bubbles |
| **Big Escape** (boss) | Three-phase chase. Right answers charge **Friendship Power**; when full, Otter and Mosey pull a team move (mud splash, banana-skin slide, tail swish…) and the chase moves on. Ends with the boss befriended. | Type | Guardian encounter |
| **Fix-It Workshop** (interlude) | Calm repair at Crash Camp: drag bolts into rows to build "3 rows of 8", slot the four fact-family gears into the part, watch it fit into the machine. | Drag | New, simple |
| **Campfire Sing-Along** (planned) | Otter and Mosey chant a times table over a beat, three rounds that leave more for the child to sing each time, then a quiz that fills the table in order. See section 14. | Sing, then type | New |

**Chase pressure** (grown-up setting), whichever is chosen, a level can't be failed:
- **Calm** (the default, confirmed): the chaser only moves closer after a wrong answer.
- **Exciting**: the chaser slowly creeps closer, so quick answers help.
- **Gentle dinosaurs**: no chasers at all, softened roars.

A voluntary **Raptor Race** (60-second quick-fire against your own best score) unlocks after
zone 5, for children who enjoy speed.

---

## 5. Rewards and trophies

Same spirit and engine as Lost Islands: three-star levels, collections, a trophy cabinet that
shows the gaps, at most two trophies handed out per level.

| Reward | How it works |
| --- | --- |
| **Stars** | 3 per level, 90 in all. |
| **Machine parts** | 6, one per zone. The Times Machine at **Crash Camp** (the map's centre) rebuilds visibly. This replaces Lost Islands' colour restoration as the big visible payoff. |
| **Fossil Museum** *(new, the learning heart)* | One dinosaur skeleton per times table, 12 bones each (×1 to ×12). A fact turning **Secure** puts its bone in place; **Fluent** turns it gold. A complete skeleton comes to life for a moment. Children *see* their times tables being learnt. Only tables the grown-up has switched on are shown; the rest are a teaser ("Ask a grown-up to switch on the 7s!"). |
| **Dino Nursery** (pets) | Baby dinosaurs hatched in Egg Hatch levels and earned on first clears (baby T-Rex reuses `icon_1f996`). They follow you on the map. About 12. |
| **Hats** | Time-traveller goggles, explorer hat, fossil-hunter hat, bone hair clip, plus the six Lost Islands hats. |
| **Crash Camp decorations** | Replaces the Home island: campfire, footprint path, fern arch, volcano lamp, plus the Lost Islands tent, lantern, flowers, palm and kite. |
| **Dino Fact cards** *(optional)* | A real fact on each first clear, read by the narrator. |

### Trophy cabinet (about 140 trophies)

- **Per level:** Superstar (3 stars) and Flawless (all right first time): 60.
- **Per zone:** Boss's Friend and Zone Champion (3 stars everywhere): 12.
- **Milestone ladders:** stars, right answers, right first time, best streak, levels, days played,
  machine parts, plus a new **Lightning** ladder (facts typed right in under 3 seconds).
- **Learning:** one per table, won by completing its skeleton (12); Missing Number Master,
  Division Detective, Counting Champ, Fact Family Fixer, Word Problem Wizard; **MTC Ready** (25/25
  in MTC practice).
- **Collections:** pets, hats, decorations, all fossils.
- **Secret:** for example *Itchy Back* (scratch Rex), *Untouchable* (finish a chase with the
  dinosaur never getting closer), *Night at the Museum* (visit the museum after 7 pm), plus the Lost
  Islands ones that still fit (Comeback, Never Give Up, No Hints, Weekend, Back for More).

The trophy rules, ladder logic, two-per-level limit, waiting list and cabinet screen are reused.

---

## 6. The grown-ups' area

Reached through a gate, as before. **Change from Lost Islands:** its gate asks a two-digit ×
one-digit sum, which a child practising tables could work out; use a sum well beyond times
tables (for example 14 × 13, or a 3-digit subtraction) plus press-and-hold.

### Settings

- **Year group presets:** Year 2 (2, 5, 10) · **Year 3 (default)** · Year 4 / MTC (2–12) · All (1–12) · Custom.
- **Times tables:** switch each of 1–12 on or off, and mark which are *focus* and which *review*.
- **Multiply up to:** ×10 or ×12.
- **Question types:** multiply, missing number, divide, count in multiples, word problems.
- **Answers:** adaptive (recommended), always pick, always type.
- **Chase pressure:** calm, exciting, gentle dinosaurs (see section 4).
- **Speed:** off (default), timed bonus points, or **MTC practice**: 25 questions, 6 seconds each,
  like the real check, scored and kept for the report.
- **Break reminder, sound, accessibility, players, restart and delete:** reused.
- **Play-test a level** without saving: reused.

### Progress report

- **The 12 × 12 grid:** every fact coloured by state (new, learning, getting there, secure, fluent).
  The single most useful picture for a parent.
- Per table: facts secure, accuracy, average answer time.
- **Trickiest facts** (missed more than once) and **slowest facts**.
- MTC practice scores over time.
- Play time, recent trophies.

---

## 7. Accessibility and wellbeing

Reused from Lost Islands: calmer motion, high contrast, easy-read text, every question read aloud by
the recorded narrator, hints, volume controls, no mandatory timers, multiple players. New:
**Gentle dinosaurs**, separate **roar volume**, and screen shake that respects reduced motion.

---

## 8. What we reuse from Lost Islands

From `../../year3/otter-and-mosey-and-the-lost-islands`.

### Art (about 65 of its 210 images)

| Reuse as-is | Items |
| --- | --- |
| Otter (7 poses) | idle, blink, cheer, oops, run, talk, think |
| Mosey (7 poses) | idle, blink, cheer, oops, swim, talk, think |
| Together | `duo_ride` (Otter riding Mosey): the Dino Dash hero sprite |
| Props | `egg`, `crystal_shard` (machine power source), `chest` |
| Pets / icons | `icon_1f996` (baby T-Rex), volcano, egg, fire, star, gem, lock, medal, map, flag, lightning, sparkles |
| Trophy badges (~27) | three-stars, perfect, tables, sharp-shooter, answers, stars, combo-5/8/9, adventurer, explorer, first-steps, never-give-up, comeback, no-hints, weekend, back-for-more, division, number-ninja, friendship, hat-trick, hats-all, decorator, pets-5, pets-all, treasure-all |
| UI | `trophy_cabinet`, `trophy_champion`, `trophy_parcel`, `logo` style |
| Rewards | 6 hats, plus tent, lantern, flowers, palm and kite decorations |
| Backgrounds | `bg_title` for the Rainbow Island opening; `bg_dragon` (volcano with nests) as a candidate for Raptor Ridge |

### New art (about 130 images, same pipeline and models)

Same tools as before: `tools/generate_art.py` with the OpenAI Images API (`gpt-image-2.5-sunburst`
for anything drawn from a reference, `gpt-image-2.5-flare` otherwise), the same five style
prompts, then `tools/import_art.py`. **Every dinosaur gets a reference picture first** and its other
poses are drawn from it, exactly as Otter and Mosey were.

| Group | Count |
| --- | --- |
| New Otter / Mosey poses: scared, running away, fixing (with spanner), in the machine, goggles | ~6 |
| Times Machine: whole, wrecked, 6 parts | ~8 |
| 6 bosses × reference, chase / roar, happy | ~18 |
| Minor dinosaurs (chasers, background) | ~12 |
| Baby dinosaur pets | ~12 |
| Fossil skeletons (one per table) and bones | ~14 |
| Backgrounds: 6 zones + foregrounds, map, title, Crash Camp, museum, ending | ~17 |
| Props: stones, nests, logs, footprints, ferns, bolts, gears | ~12 |
| New badges, hats, decorations | ~25 |
| Logo, app icon | 2 |

Lost Islands spent about **$7.50** on ~210 images. Estimate here: **about $9, cap at $15**
(`ART_BUDGET_USD=15`).

### Sound and voices (all ElevenLabs, as before)

| Reuse | Detail |
| --- | --- |
| **19 sound effects** | tap, key, nav, correct, combo, wrong, pop, star, jump, swim, crack, chirp, plank, portal, friendship, levelComplete, victory, unlock, whoosh. |
| **Otter and Mosey voices** | Saved in the ElevenLabs account (Otter `sYN0fMdsZGmW5GjQDfRo`, Mosey = Daniel `onwK4e9ZLuTAKqWW03F9`), with the same settings and tags, so new lines match exactly. |
| **Narrator "Alice"** | Same voice and settings for questions and story lines. |
| **216 times-table clips** | Every 2, 3, 4, 5, 8 and 10 fact as a product, a missing number and a division, already recorded. That covers the whole default Year 3 set. |
| Other lines | The 4 "ask a grown-up" lines, Otter's "Three! Two! One!" photo countdown. |
| Music | `music_title` for the Rainbow Island opening; `music_dragon` as a stand-in for Raptor Ridge. |

| New | Detail |
| --- | --- |
| Narration | The 1, 6, 7, 9, 11 and 12 tables (216 clips) so any custom choice is fully voiced; "count in 3s"-style instructions; the word problems; Dino Fact cards. |
| Dialogue | About 150 Otter and Mosey lines, plus the boss lines (see question 1). |
| Dinosaur voices | Designed with Voice Design, one per boss, as funny adult performers (ElevenLabs won't make children's voices; dinosaurs don't need them). |
| Sound effects (~22) | A roar for each boss scaled by Roar Rating (T-Rex biggest, still not horrible), stomps, ground rumble, tail swish, wing flaps, raptor chirps, egg wobble, snore, time-machine whirr / sputter / crash, spanner clank, bolt, cog click, stone splash and sink, mud squelch, camera shutter. |
| Group cheer | Re-mixed with the new cast (dinosaur roars as the "hooray"), using `cheer.mjs`. |
| Music (~8 loops) | Title, map / Crash Camp, one per zone with intensity rising, a chase layer for Big Escapes. |

Rough ElevenLabs text use: about 20,000 characters of speech, within one month of the Starter
plan's 40,000. Sound effects and music cost more per second; check the balance with each script's
count option before recording.

### Code

Reused almost whole: the platform-neutral core package (learner model, spaced repetition, sessions,
progression, trophies, versioned save files), the times-table generator (it already supports chosen
tables and multipliers), audio manager, narration and talking-mouth animation, character nodes,
dialogue, HUD, number pad, effects, backdrop, trophy cabinet, collection, grown-up gate and
dashboard, finale and group photo, debug launch arguments, content / art / audio tooling, the
play-test runner and the web port's structure.

Removed: spelling, word bank, typing, Word Blaster and Typing Turbo as they stand (their bubble and
runner pieces are kept for Sky Snatch and Dino Dash).

---

## 9. Technical approach

### Project

Confirmed: **fork Lost Islands into this folder** and rename it, rather than building a shared
library both games use. It's the fastest route, keeps the finished Lost Islands untouched, and
the shared pieces can be pulled into an "Otter & Mosey kit" later if a third game comes along.

- `git init` here; Xcode project `PrehistoricTimes`; core package `PrehistoricTimesCore` (Foundation
  only, no UIKit, SwiftUI or SpriteKit, so the web port stays straightforward).
- Bundle ID following the existing pattern: `otter-and-mosey-t-rex-times-trouble.dev.skynolimit`.
- Swift 6, SwiftUI for menus and grown-ups, SpriteKit for scenes, iOS / iPadOS 26+, landscape.
- Content in plain JSON (`zones.json`, `dialogue.json`, `narration.json`, `problems.json`) built by
  `tools/build_content.py` from `tools/content/zones.py`.
- New save file name and version 1, so nothing is confused with Lost Islands saves.
- Secrets as before: `ELEVENLABS_API_KEY` in a git-ignored `.env.local`,
  `OPENAI_API_KEY_CHATGPT_GRAPHICS` from the environment (`bw-reload`). Nothing at runtime.

### Core changes

- `FactStats`: per-fact first-try history, response times and the state ladder in section 3.
- `QuestionPlanner`: the focus / review / secure mix, new-fact pacing and in-level re-asks.
- `ZonePlan`: maps the grown-up's tables onto zones.
- `AnswerStyle`: pick or type, per fact and setting.
- `Fossils`: bones and skeletons derived from fact states (no extra saved state).
- `MTCPractice`: the 25-question, 6-second session and its scoring history.
- Trophy rules for the new ladders and learning trophies.

### Testing

- Core unit tests (Swift Testing): fact correctness for every table 1–12, distractors never equal
  the answer, planner mix, spaced-repetition timing, zone mapping for unusual table choices,
  stars, trophies, save round-trips.
- App tests: every mode builds and asks a question; all art and audio is bundled; progress
  survives a relaunch.
- The existing `tools/playtest` runner, adapted: simulator play-throughs on iPhone and iPad.

---

## 10. Milestones

| # | Milestone | Done when |
| --- | --- | --- |
| M0 | **Foundation** ✅ (19 Nov 2026) | Fork, rename, strip spelling and typing, `git init`; builds and tests pass on an iPhone and iPad simulator. |
| M1 | **Learning engine** ✅ (19 Nov 2026) | Fact tracking, planner, zone mapping, answer styles, grown-up settings model, with tests. |
| M2 | **Look and sound check** ✅ made, awaiting your review (19 Nov 2026) | Times Machine, new Otter / Mosey poses, Mama Maia and Trevor references, two zone backgrounds, first roars and dinosaur voice previews. **You review these before more is generated:** [docs/m2-review/index.html](m2-review/index.html). |
| M3 | **Vertical slice** ✅ built (19 Nov 2026) | Opening story and crash, Crash Camp map, Hatchling Hollow complete (4 levels, Big Escape, Fix-It Workshop), stars, first trophies, Fossil Museum, dinosaur music. **Play-test with a child here.** |
| M4 | **Zones 2–6** ✅ built (20 Nov 2026) | All five zones written, drawn, voiced and scored: 25 more levels, four new bosses (Steggy, the Swoop Squad, the Snatch Pack, Rex) with chase, happy and sleeping poses, five backgrounds and foregrounds, five zone tunes, three new roars, four baby-dinosaur pets, a new group photo, and the finale moved to Crash Camp. Voices: Rex is a designed voice (the account's last free slot); Steggy (Lily), the Swoop Squad (Callum) and the Snatch Pack (Laura) use ElevenLabs premade voices, which take no slot, so no Lost Islands voices had to be deleted. Sky Snatch and the Raptor Race are left for M5. |
| M5a | **Campfire Sing-Along** ✅ built (21 Nov 2026) | Section 14: song plan and quiz rules with tests, 203 song clips and the dialogue recorded, an 8-bar backing loop cut from the approved test beat, the AVAudioEngine song player, the sing-along screen, the song shelf, zone warm-ups, rewards, trophies, grown-up settings, new art (Otter singing and listening, Mosey singing, the sing-along badge) and a UI play-through test. Instrument props for the band are still emoji. |
| M5 | **Rewards** ✅ built (22 Nov 2026) | The Dino Nursery (12 baby dinosaurs, the newest three trotting behind Otter and Mosey on the map), 9 hats (fossil-hunter hat, bone hair clip and Mama Maia's bow from the Big Escapes, plus the goggles and Lost Islands hats), 11 Crash Camp decorations (footprint path, fern arch, volcano lamp and a dino skeleton replace the last Lost Islands ones; older saves are moved over), a 159-trophy cabinet (Raptor Racer ladder, Fact Family Fixer, MTC Ready, Camp Designer, Fossil Hunter, Dino Expert, and the secrets Itchy Back, Untouchable and Night at the Museum), 30 narrated Dino Fact cards (one per level, given on the first clear and kept under Treasures → Facts), museum skeletons that come to life when complete and tapped, **Sky Snatch** (Pterodactyl Peaks level 2) and the **Raptor Race** (after Raptor Ridge). The band's instruments are painted. 24 new pictures ($0.38). |
| M6 | **Grown-ups** ✅ built (22 Nov 2026) | Year-group presets (Year 4 switches on check practice), the times-tables report (12 × 12 grid by fact state, each table's secure facts, accuracy and typical time, trickiest and slowest facts, check and race scores), **Times Tables Check practice** (25 questions from the 2 to 12 tables, 6 seconds each with 3-second gaps, no feedback until the end, scores kept), a new gate (a three-digit subtraction with exchanging, then press and hold), Gentle dinosaurs and a separate roar volume. |
| M7 | **Polish and QA** ✅ mostly (22 Nov 2026) | Checked on iPhone 17 Pro and iPad mini. VoiceOver can now answer in every mode (answers placed in a scene are also offered as buttons), boss speech badges sit above or beside the head instead of on it, Skip is gone (dialogue says "Tap anywhere to continue"), Otter and Mosey face the right way in the Raptor Race. Runner: core 131 tests, app 14, iPhone UI suite all green; iPad all green except `testCampPetKeepsItsNewRoamingSpot`, which has failed on iPad since 20 Nov (the dragged pet stops short beside the palm tree). Still to do: that test, and the 3 Sky Snatch ending lines once the ElevenLabs quota resets (see `tools/content/islands.py`). |
| M8 | **Web version** | See below. |

---

## 11. Web version (after iOS is finished)

Planned on 22 November 2026. **Start once M7 is done and the iOS work is committed**, so the
port happens once, against a finished core. Published at
`https://otterandmosey.com/play/prehistoric-times/`, alongside Lost Islands, with a detail page
at `/games/prehistoric-times/`.

Keeping every rule in the core package (and nothing clever in the scenes) is what makes this port
mostly mechanical.

### Part A: the web game (`web/` in this folder)

The same approach Lost Islands is using: TypeScript, Vite and PixiJS, copied from its `web/`
rather than shared (decision 3 in section 13).

1. **Setup.** Copy Lost Islands' Vite, TypeScript and PixiJS setup, and `web/src/engine` as it is.
   Point the `@content` alias at the `PrehistoricTimesCore` JSON, and `sync-assets.mjs` at this
   game's `Assets.xcassets` (about 38 MB) and `Resources` (about 27 MB). The "All adventures"
   link comes from `VITE_GAMES_HOME`, as in Lost Islands.
2. **Core port.** `web/src/core`: a TypeScript port of `PrehistoricTimesCore` (about 3,100 lines of
   Swift): fact tracking, question planner, zones, answer styles, fossils, song plans, sessions,
   progression, trophies and saves.
   - Saves under a new browser key, `prehistoric-times.save`, in the same JSON shape as the Swift
     save, so they never collide with Lost Islands (`lost-islands.save`).
   - Port the core tests (about 1,500 lines).
   - Extend the parity test (`swift-contract.json`, as in Lost Islands) so Swift and web produce
     identical results for stars, trophies, fact states, seeded planner output and song timelines.
3. **Scenes.** The opening story and crash, then Egg Hatch, Dino Dash, Stepping Stones, Tiptoe
   Past and the Big Escape, plus whatever M5 adds (Sky Snatch, Raptor Race). Then characters,
   backdrops and effects.
4. **Screens.** Crash Camp map, Fix-It Workshop, Fossil Museum, trophies, the M5 rewards (Dino
   Nursery, hats, decorating, Dino Fact cards), the finale and the M6 grown-ups' area (presets,
   12 × 12 report, MTC practice, gate, Gentle dinosaurs). As in Lost Islands, these are web
   layouts in the game's style rather than copies of the iOS screens.
5. **Sing-along.** The riskiest piece (about 1,150 lines of UI plus the song player). The Web
   Audio API schedules the clips against `AudioContext.currentTime`; each song's clips are
   decoded before it starts; audio unlocks on the first tap, as iPhone and iPad Safari require;
   "Fill the ladder" becomes a typed quiz.
6. **Load weight.** About 65 MB of assets is too much to load at once on a phone: load art and
   audio per zone, and song clips per table.
7. **Testing.** Vitest for the core; Playwright play-throughs in Chromium and mobile WebKit, with
   `?level=hollow-1` and `?short`. Then switch on the browser layers in `tools/playtest`.

### Part B: otterandmosey.com changes (`website/`)

- **`src/catalogue.mjs`:** add the second game. Each entry also gets its own source folder, card
  art, card tag and background scenes. Card tags: "Times tables · Ages 7–9".
- **`scripts/build.mjs`:** it assumes one game today (`games[0]` and a single game folder). Rework
  it so each game takes artwork from its own folder, builds with its own base path
  (`--base=/play/<slug>/`) and gets its own favicon.
- **Homepage:**
  - A neutral hero, "Choose your adventure", scrolling to `#games`; the nav's "Let's play" goes
    to `/#games`.
  - Two matching game cards. The Prehistoric Times card could use `bg_camp` with `duo_machine` or
    `island_rex`. Each card has its own tag; "OUR FIRST ADVENTURE" stays on Lost Islands only.
  - The page description names both games.
- **Rotating backgrounds:** add Prehistoric scenes (for example Hatchling Hollow, the swamp, the
  peaks and Crash Camp). Prefix scene ids with the game, because both games have `bg_title` and
  `bg_woods`, and check that an old saved scene id still falls back cleanly.
- **Grown-ups section and FAQ:** answers cover both games, say that each game saves separately in
  the browser, and link to both detail pages.
- **New detail page `/games/prehistoric-times/`,** written specially for this game like the Lost
  Islands one: the time-machine story, the six zones with their art, the learning (adaptive 1–12
  tables and division, calm by default, the sing-along, the Fossil Museum), how to play and how
  saves work.
- **Privacy page:** each game has its own save; the sing-along uses no microphone.
- **Plumbing:** the new pages in the sitemap; `/healthcheck` in `server.mjs` checks both game
  entry files; the new pages in `test/site.test.mjs`; both READMEs updated; M8 marked done here.
  The server's trailing-slash redirect already works for any game path.

### Release

Release the website changes and the game together: build, run the tests, then check a level,
audio, a sing-along and saved progress in a browser. Deploy with the existing `node_project.zsh`
command after approval. The build rebuilds both games and the release gets bigger, so check the
size on Mini, and consider a way to skip rebuilding a game that hasn't changed.

### Still open

- Card wording: Lost Islands reads "Otter and Mosey and / The Lost Islands"; proposed "Otter and
  Mosey in / Prehistoric Times".
- Should the card also say "iPhone & iPad · Coming soon", given the App Store question below?
- A play-test of the web version with a child before it goes on the homepage?

---

## 12. Risks

| Risk | Mitigation |
| --- | --- |
| Too scary for some children | Comic chases, nobody hurt, befriending endings, Gentle dinosaurs setting, roar volume. |
| Time pressure causing maths anxiety | Calm by default, stars from accuracy only, speed always optional. |
| Drill fatigue (it's all times tables) | Seven modes, short levels, story between zones, visible progress in the museum and the machine. |
| Dinosaurs looking different in each pose | One reference per dinosaur first, all poses drawn from it. |
| Mosey on dry land | Ride and swim poses for chases; swamp and river zones for his swimming; new running pose if needed. |
| Swift and web rules drifting | Contract tests, as in Lost Islands. |

---

## 13. Open questions

Decided on 19 November 2026:

1. **Dinosaur endings:** escape, then befriend (each boss has a funny reason for being cross).
2. **Default chase pressure:** calm; the chaser moves only after a wrong answer.
3. **Code:** fork Lost Islands into this folder; extract a shared kit later if a third game needs it.
4. **First release:** 30 levels across 6 zones, plus a Fix-It Workshop after each zone.

Decided on 20 November 2026, for the sing-along (section 14):

5. **Where:** both a song shelf at Crash Camp and a one-off warm-up song at the start of zones 1–4.
6. **Audio:** a chant over a beat, using the existing Otter and Mosey voices, built while
   playing so it works for any table and any highest multiplier.
7. **Wording:** "Four times three is twelve", matching the game's narration ("4 times 3").
8. **Quiz:** "Fill the ladder": in order, typed, untimed. "Beat Catch" is not built.
9. **Learning record:** in-order quiz answers count as practice only; the shuffled challenge
   counts in full.
10. **Microphone:** none.

Decided on 22 November 2026, for the web version (section 11):

11. **Name and address:** Prehistoric Times, at `otterandmosey.com/play/prehistoric-times/`.
12. **When:** after M7, not alongside the iOS work.
13. **Homepage:** a neutral hero and two equal game cards; backgrounds rotate through both games.

Still open, no rush:

- Should the boss dinosaurs talk (designed voices), or only roar while Otter and Mosey do the
  talking? Proposed: they roar during chases and talk once befriended.
- Names: Mama Maia, Trevor, Steggy, the Swoop Squad, the Snatch Pack and Rex are placeholders.
- Is this for the family only (TestFlight / direct install, like Lost Islands) or the App Store?
  The App Store's Kids category has extra rules on gates and data, which the design already meets.
- Include ×0 facts? (Not in the Year 3 curriculum or the MTC; proposed: no.)

---

## 14. Campfire Sing-Along (planned 20 November 2026)

Learning a times table by heart through a song: Otter and Mosey chant it with the child round a
campfire, the child sings more of it each time, then fills it in on the number pad. The design
choices are confirmed (section 13, items 5–10). Mock-ups, made from the game's own art:
[docs/singalong-review/index.html](singalong-review/index.html).

### Where it lives

- **Song shelf at Crash Camp.** A "Sing-Along" button on the Crash Camp card opens a shelf with
  one record for each table the grown-up has switched on. Any song can be sung any time, as often
  as the child likes. A record is black until the song has been sung and its quiz finished, then
  silver, then gold once the table's skeleton in the Fossil Museum is complete (every fact secure),
  so the shelf and the museum always agree. It shows the best quiz stars.
- **A song before the first level of each zone** (21 Nov 2026 every level had one; on 22 Nov
  that proved too many, so by default only each zone's first level opens with a song, and only
  until it is cleared: six in the whole adventure). A grown-up can choose every level, or never.
  The song is about a minute of its table's song: the level's own table if it has one,
  otherwise the zone's focus tables taking turns level by level. What is sung moves on as the
  child does: round 1, then round 2, then Rex speed, then filling the ladder, then the fastest
  round, the shuffle challenge and the ladder in turn (`SingAlong.nextSegment`). A start card says
  what's coming ("Warm-up: the 2s song · Sing with us! · Then on to Fern Dash"); afterwards, "On to
  Fern Dash!". Unstarred and can't be failed; there is no Skip (removed 22 Nov 2026).
  Play-testing from the grown-ups' area skips them.
- **Crash Camp:** a campfire band (log drum, ukulele, maracas) stands on the dirt beside the fire,
  a fixed obstacle the pets walk round, and opens the shelf. The shelf lists the songs in number
  order; "Next up!" marks the easiest one whose friend hasn't been met.
- **Song friends** (added 21 Nov 2026): every table's song has its own baby dinosaur musician,
  met the first time the song is sung right through: Ding (1, triangle), Toot (2, trumpet),
  Tambo (3, tambourine), Plink (4, xylophone), Bongo (5, bongos), Flutey (6, flute), Oompah (7,
  tuba), Strum (8, guitar), Shaka (9, maracas), Roary (10, microphone), Thump (11, big drum) and
  Fiddle (12, violin). Until then the shelf shows a dark shape. Singing again moves a friend on:
  sparkling after 4 plays (songs sung through, ladders filled and shuffles done) and crowned after
  8. The shelf and the level's start card say what's next ("2 more to make Tambo sparkle"), the
  reward screens announce each step, met friends are the first to come and sing in every song,
  and two trophies go with them: The Whole Band (meet every shelf friend) and Encore! (crown one).
- **Friends join in:** a baby dinosaur or friend arrives for every line sung and every right
  answer, standing in a front row that fills in from both ends, then a middle and a back row (42
  on screen; any more show as "+N", so the count at the top always matches), with a banner
  at the end of each round ("Round 1 done! 12 friends are singing with you!") and a line-up on the
  level's "on to" screen.

### The song

The table is sung from 1 × up to the grown-up's highest multiplier (`usableMultipliers.max()`,
normally 12). Every line takes two bars of 4/4 over a backing beat, in call and response: Otter
sings the question ("Four times three is…") and Mosey sings the answer ("twelve!"). That is about
a minute for each round of 12 lines.

| Round | Speed | Bar 1 | Bar 2 | On screen |
| --- | --- | --- | --- | --- |
| 1. Sing with us | 🐢 about 88 bpm | Otter: "Four times three is…" | Mosey: "twelve!" | The whole line, lit word by word with a hopping footprint |
| 2. You finish it | 🦕 about 100 bpm | Otter: "Seven times three is…" | The child sings; on beat 3 the egg hatches and Mosey says "twenty-one!" | The answer is an egg that wobbles for a beat |
| 3. Rex speed! | 🦖 about 112 bpm | Otter: "Nine times three is…", everyone sings along | Mosey: "twenty-seven!" as the egg cracks | "9 × 3 = 🥚": the answer stays in its egg until it's sung, so the child has to know it to keep up |

- **The ladder:** a panel listing the whole table, building up as it is sung, so the child sees
  the pattern (3, 6, 9, 12 …). In rounds 2 and 3 the answers still to come are eggs.
- **The band:** each befriended boss joins as their zone is cleared: Mama Maia on maracas, Trevor
  on drums, Steggy plays her tail spikes like a xylophone, the Swoop Squad are backing singers
  ("backing *pterosaurs*, actually"), the Snatch Pack on shakers, and Rex stomps the big drum with
  his feet because his arms don't reach.
- **Stomp drum:** a big button to tap along with the beat: a heavy stomp sound (`stomp_big`), a
  thump you can feel, the screen shakes, every friend hops, and "BOOM!" (bigger, with a sparkle,
  on the beat). Nothing is scored. Reduced motion keeps the sound but not the shake.
- Grown-ups can set the number of rounds (1–3, default 3) and switch the speed-up off. Reduced
  motion stops the bouncing and dancing; the words still light up.
- No microphone: the game never listens. Otter's "Your turn!" is all the prompting.

### The quiz: "Fill the ladder"

- The same lines **in order**, typed on the game's number pad, with the ladder on the left
  filling in. The band plays a soft one-bar loop and waits: there is no timer.
- **First miss:** the band sings that line again as the hint, then the child tries again.
  **Second miss:** the answer appears, and the line comes back once more after the last one.
- **Stars** from first-try accuracy, using the usual rule (85% for 3, 55% for 2, finishing always
  earns 1).
- **Shuffle challenge** straight after the ladder, with no menu in between ("Ladder done! Now all
  mixed up!"): six facts from the same table in random order. One results screen covers both. Chanting in order tends to teach children to count up from the start ("1 × 3 is 3,
  2 × 3 is 6 … 7 × 3 is 21") instead of recalling the fact; mixing the order breaks that habit.
  The levels then carry on asking the table in random order.
- **Learning record:** in-order answers are easier (each one follows from the last), so they
  count as **practice only**: a new `FactStats.recordPractice(correct:)` can move a fact from New
  to Getting there but never further, and adds no streak days or timings. A miss counts as a
  normal miss. The shuffled challenge records answers in full, like any level.

### Rewards

- Stars and the record's colour on the shelf.
- The table's fossil appears beside the quiz; its bones glow as answers go in. Bones are still
  only *placed* in the museum when a fact becomes secure, as now.
- Trophies: a **Sing-Along Star** ladder (1, 5 and 20 songs sung), **Rex Speed** (finish a
  round 3), **Gold Record** (first gold record) and **Whole Songbook** (every switched-on song
  sung). The two-per-level limit and waiting list apply.
- The reward screen: "You learned the 3s song!", stars, the spinning record, the fossil doing a
  dance, then **Sing again**, **Shuffle challenge** or **Back to camp**.

### Audio

All ElevenLabs, as for the rest of the game.

| Item | Detail | Size |
| --- | --- | --- |
| Backing loop | One instrumental campfire stomp at 100 bpm in 4/4 (log drums, ukulele, marimba, tuba), cut to an exact number of bars so it loops on the beat. The quiz's waiting loop is the same track, filtered and quieter. | 1 track, about 60 s |
| Otter's calls | "*N* times *T* is…" for every table 1–12 and multiplier 1–12, in a rhythmic, chanting delivery. | 144 clips, about 2,900 characters |
| Mosey's answers | Every product in the 12 × 12 table ("twelve!", "twenty-one!"), shared by all tables. | 59 clips, about 600 characters |
| Dialogue | Song intros, "Your turn!", "Faster!", "Rex speed!", the outro and quiz praise, for the content pipeline as usual. | About 25 lines, about 1,000 characters |

About 4,500 characters of speech in all: a fraction of a month's plan. New keys: `sing_q_3x4`,
`sing_a_12`, generated by `tools/build_content.py` and recorded by `narrate.mjs`; the backing
loop goes in `music.json`.

**Audio test first.** Before recording everything: two or three lines of the 3s over a short test
beat, in two deliveries (rhythmic speech and half-sung), at the three speeds, for you to listen
to. This settles how chant-like the voices can sound and how fast each round should be. It also
decides whether a short sung chorus with no numbers in it (option C from the review) is worth
adding.

**Audio test done (20 November 2026): the chant was chosen** over the half-sung delivery. Tags:
Otter `[excited, chanting rhythmically]`, Mosey `[chanting rhythmically, cheerful]`. ElevenLabs
Music came out at exactly 100 bpm, starting on the beat, so the loop can be cut to whole bars.
The test is `tools/sfx/singalong-test.mjs` (recording, beat detection) and
`tools/sfx/singalong-render.swift` (an offline AVAudioEngine render, the song player's
prototype); its output is in the git-ignored `tools/sfx/samples/singalong-test`.

### Art

Same pipeline and references (`tools/generate_art.py`), about 10 images, under $1:

- Otter singing, Otter cupping an ear ("Your turn!"), Mosey singing.
- Instrument props for the six bosses, layered over their existing happy poses.
- Records, the ladder, the lyric card and the drum are drawn in code; the stage is `bg_camp`.

### Technical approach

**Core (`PrehistoricTimesCore`, Foundation only, so the web port stays mechanical):**

- `SongPlan`: the table, the lines (1 to the highest multiplier), the rounds, and a timeline in
  beats of every cue: which clip plays, what is hidden and when it is revealed. Pure and fully
  testable; the app just plays it.
- `SongQuiz`: an in-order session with the hint, second-miss and re-ask rules, and the stars.
  The shuffled challenge reuses the normal `Session` with a single table.
- `FactStats.recordPractice(correct:)`, as above.
- Save data: `Profile.songs: [Int: SongRecord]` (times sung, rounds finished, best stars, last
  sung), defaulting to empty so existing saves load unchanged.
- Trophy rules for the new trophies; `Fossils` provides the gold-record test.
- Contract tests so the web port can't drift.

**App:**

- `SongPlayer`: the current `AudioManager` uses `AVAudioPlayer`, which can't keep clips on the
  beat. The new player uses `AVAudioEngine`: the backing loop and the voices on their own
  `AVAudioPlayerNode`s, each clip scheduled at an exact sample time, and an `AVAudioUnitTimePitch`
  so the speed-ups don't make anyone sound like a chipmunk. The words, the footprint and the band
  follow the player's clock, not a timer. It respects the music and voice volumes and pauses
  cleanly.
- `SingAlongView` (SwiftUI, like the Fix-It Workshop): the stage, Otter, Mosey and the band
  bobbing on the beat, the lyric card, the ladder, the drum and the quiz's number pad, all driven
  by the song player's clock.
- `SongShelfView` (SwiftUI), new routes for the shelf and a song, the Crash Camp button and the
  warm-up stop on the zone screen.
- Grown-ups' area: rounds, speed-up on or off, zone warm-ups on or off. The progress report
  lists songs sung.
- Debug: `-debugRoute song:3` opens the 3s song; `-debugShort` cuts a song to three lines.

**Web version:** the Web Audio API schedules clips against `AudioContext.currentTime` the same
way, so the song player ports directly.

### Testing

- Core: the plan stops at the highest multiplier (×10 gives 10 lines; any set of multipliers
  uses its highest), each round hides the right parts, cue times only move forward, the quiz order
  and re-asks, stars, practice answers never make a fact secure, and old saves load.
- App: the song scene builds and plays a whole round silently; every `sing_` clip for tables
  1–12 is bundled (`check_playtest_assets.py`); a UI play-through of a short song and its quiz on
  iPhone and iPad through `tools/playtest`.

### Steps

All done on 21 November 2026 except the boss instrument props (the band holds emoji for now).
Recording used about 4,100 ElevenLabs credits (delivery tags are not charged) and the art $0.20.

1. Audio test, for your approval.
2. Core rules and tests.
3. Record the clips and the backing loop; draw the new poses.
4. Song player, sing-along scene and song shelf.
5. Quiz, shuffle challenge and rewards.
6. Zone warm-ups, grown-up settings, trophies, play-test on both simulators.

### Risks

| Risk | Mitigation |
| --- | --- |
| Spoken clips sound stiff rather than musical | The audio test comes first; rhythmic delivery tags; a sung chorus as a fallback. |
| Clips drifting off the beat | Sample-accurate scheduling on one audio clock; every clip trimmed of leading silence when recorded. |
| Learning the order rather than the facts | The shuffle challenge, practice-only credit for in-order answers, and the levels' random order. |
| Too long for some children | Rounds set by grown-ups; about a minute per round; can leave any time and start again. |
