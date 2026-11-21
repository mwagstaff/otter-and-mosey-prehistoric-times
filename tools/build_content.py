#!/usr/bin/env python3
"""Builds the JSON content bundled with TimesTroubleCore from tools/content.

Run from the repository root:  python3 tools/build_content.py
The JSON files are the cross-platform source of truth for web and Android ports.
"""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
out = root / "Packages/TimesTroubleCore/Sources/TimesTroubleCore/Resources"
out.mkdir(parents=True, exist_ok=True)
# The narrator's script: clip key -> exactly what is said. tools/sfx/narrate.mjs records these,
# and the app plays the clip whose key matches a question's `audioKey`.
narration = {}
# Every fact from 1 × 1 to 12 × 12, so any tables a grown-up picks are read aloud.
for table in range(1, 13):
    for other in range(1, 13):
        narration[f"mul_{table}x{other}"] = f"{other} times {table}."
        narration[f"mulq_{table}x{other}"] = f"What times {table} makes {table * other}?"
        narration[f"div_{table}x{other}"] = f"{table * other} divided by {table}."
narration.update({
    "skill_multiplication": "Multiply the two numbers.",
    "skill_missingNumber": "Find the missing number.",
    "skill_division": "Share the first number equally.",
    "skill_sequences": "Which number is missing from the pattern?",
    "skill_wordProblems": "Read the number story, then work out the answer.",
})
(out / "narration.json").write_text(json.dumps(narration, indent=0, ensure_ascii=False) + "\n")
sys.path.insert(0, str(root / "tools/content"))
import islands as source
level_ids = [l["id"] for i in source.ISLANDS for l in i["levels"]]
reward_ids = {r[0] for r in source.REWARDS}
for island in source.ISLANDS:
    for l in island["levels"]:
        if l["reward"] and l["reward"] not in reward_ids: sys.exit(f"unknown reward {l['reward']}")
if len(set(level_ids)) != len(level_ids): sys.exit("duplicate level ids")
# Dialogue that is voiced (Otter, Mosey, the guardians and the story narrator): clip key -> who
# says it, where, and the words.
# The key is a hash of "speaker:text", computed the same way by DialogueLine.audioKey in Swift.
def line_key(line):
    value = 0x811C9DC5
    for byte in line.encode("utf-8"):
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"line_{value:08x}"

dialogue = {}
def collect(scene, lines, guardian=None, mood=None):
    for line in lines:
        speaker, text = line.split(":", 1)
        if speaker == "g" and guardian:
            # Guardians are recorded under their kind (tree, octopus, ...), one voice each.
            entry = {"speaker": guardian, "scene": scene, "text": text}
        elif speaker in ("o", "m"):
            entry = {"speaker": "otter" if speaker == "o" else "mosey", "scene": scene, "text": text}
        else:
            # Story lines, read by the question narrator.
            entry = {"speaker": "narrator", "scene": scene, "text": text}
        if mood:
            entry["mood"] = mood
        dialogue.setdefault(line_key(line), entry)
collect("intro", source.INTRO + source.INTRO_AFTER)
collect("workshop", source.WORKSHOP["intro"] + source.WORKSHOP["done"])
collect("singalong", [line for lines in source.SINGALONG.values() for line in lines])
collect("help", source.ASK_GROWN_UP)
# Zones still to come keep placeholder lines, which are never recorded.
ready = [island for island in source.ISLANDS if island.get("ready", True)]
for island in ready:
    kind = island["guardian"]["kind"]
    for l in island["levels"]:
        collect(l["id"], l["intro"] + l["outro"], guardian=kind)
    boss = island["levels"][-1]["id"]
    collect(boss, island["guardian"]["phases"], guardian=kind)
    # Once won over, the guardian sounds different: these lines get the "befriended" delivery.
    collect(boss, island["guardian"]["befriended"], guardian=kind, mood="befriended")
if len(ready) == len(source.ISLANDS):
  collect("finale", source.FINALE["opening"] + source.FINALE["thanks"] + source.FINALE["photo"] + source.FINALE["countdown"] + source.FINALE["after"])
for island in source.ISLANDS:
    if island["id"] not in source.FINALE["guardians"]: sys.exit(f"finale has no thank-you from the {island['id']} guardian")
for island in ready if len(ready) == len(source.ISLANDS) else []:
    collect("finale", [source.FINALE["guardians"][island["id"]]], guardian=island["guardian"]["kind"], mood="befriended")
(out / "dialogue.json").write_text(json.dumps(dialogue, indent=0, ensure_ascii=False) + "\n")
catalogue = {
    "islands": source.ISLANDS,
    "rewards": [{"id": r[0], "kind": r[1], "name": r[2], "emoji": r[3]} for r in source.REWARDS],
    "intro": source.INTRO, "introAfter": source.INTRO_AFTER, "askGrownUp": source.ASK_GROWN_UP, "workshop": source.WORKSHOP, "singAlong": source.SINGALONG,
    "finale": source.FINALE,
}
(out / "islands.json").write_text(json.dumps(catalogue, indent=1, ensure_ascii=False) + "\n")
print(f"{len(level_ids)} levels, {len(dialogue)} voiced dialogue lines ({sum(len(d['text']) for d in dialogue.values())} characters), {len(narration)} narration lines ({sum(len(t) for t in narration.values())} characters)")
