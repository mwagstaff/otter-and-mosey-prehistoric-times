"""Authoring source for islands.json: the six dinosaur zones, their levels, dialogue and rewards.
Run tools/build_content.py after editing.

Dialogue lines are "speaker:text" with o = Otter, m = Mosey, g = the zone's boss dinosaur, n = narrator.
A zone with "ready": False is a placeholder until its milestone: it appears on the map as
"Coming soon", and its lines are not sent for recording.
"""

def level(id, title, mode, skills, count, intro, outro, reward=None, blurb=""):
    return {"id": id, "title": title, "mode": mode, "skills": skills, "count": count,
            "intro": intro, "outro": outro, "reward": reward, "blurb": blurb}

def coming_soon(zone, modes, rewards):
    """Five placeholder levels for a zone that isn't built yet (the last is its Big Escape)."""
    levels = []
    for index, (mode, skills) in enumerate(modes, 1):
        levels.append(level(f"{zone}-{index}", f"Coming soon {index}", mode, skills, 9 if mode == "guardian" else 6,
                            ["o:Coming soon!"], ["m:Coming soon!"], rewards[index - 1] if index <= len(rewards) else None,
                            "Coming in the next update"))
    return levels

REWARDS = [
    # id, kind, name, emoji. Art is reward_<id> where it exists, otherwise the emoji.
    ("pet-pip", "pet", "Pip the baby Maiasaura", "🦕"),
    ("hat-goggles", "accessory", "Time-traveller goggles", "🥽"),
    ("deco-campfire", "decoration", "Campfire", "🔥"),
    ("pet-nubbin", "pet", "Nubbin the baby Triceratops", "🦏"),
    # Placeholders for the zones still to come (Lost Islands art).
    ("pet-chomp", "pet", "Chomp the baby T-Rex", "🦖"),
    ("hat-leaf", "accessory", "Leafy explorer hat", "🍃"),
    ("deco-flowers", "decoration", "Flower patch", "🌸"),
    ("pet-butterfly", "pet", "Breeze the butterfly", "🦋"),
    ("pet-turtle", "pet", "Shelly the turtle", "🐢"),
    ("hat-pirate", "accessory", "Captain's hat", "🏴‍☠️"),
    ("deco-mushroom", "decoration", "Glow mushroom", "🍄"),
    ("pet-crab", "pet", "Pinchy the crab", "🦀"),
    ("pet-owl", "pet", "Hoot the owl", "🦉"),
    ("hat-shades", "accessory", "Star shades", "🕶️"),
    ("deco-kite", "decoration", "Rainbow kite", "🪁"),
    ("pet-firefly", "pet", "Flicker the firefly", "✨"),
    ("pet-cinder", "pet", "Cinder the lizard", "🦎"),
    ("hat-crown", "accessory", "Golden crown", "👑"),
    ("deco-lantern", "decoration", "Lava lantern", "🏮"),
    ("pet-ember", "pet", "Ember the fire hatchling", "🐲"),
    ("pet-comet", "pet", "Comet the star pup", "🐶"),
    ("hat-wizard", "accessory", "Wizard's top hat", "🎩"),
    ("deco-rainbow", "decoration", "Rainbow arch", "🌈"),
    ("pet-moonmoth", "pet", "Luna the moon moth", "🌙"),
    # Crash Camp decorations earned with stars (see Catalog.starDecorations).
    ("deco-palm", "decoration", "Palm tree", "🌴"),
    ("deco-fountain", "decoration", "Fern fountain", "⛲"),
    ("deco-castle", "decoration", "Sandcastle", "🏰"),
    ("deco-tent", "decoration", "Party tent", "🎪"),
]

ISLANDS = [
 {"id": "hollow", "name": "Hatchling Hollow", "tagline": "Eggs, nests and one very fussy mum", "focus": "Warm-up tables",
  "colour": "#7BC86C", "roar": 1, "part": "cog", "partName": "Cog", "ready": True,
  "guardian": {"name": "Mama Maia", "kind": "maia",
   "phases": ["g:Shoo! Shoo! Nobody touches my shiny egg!",
              "g:Still here? Oh, my poor nerves! Off you go, you little rascals!",
              "g:Wait. Since when do eggs go tick-tock?"],
   "befriended": ["o:Mama Maia, it isn't an egg. It's the Cog from our time machine!",
                  "g:Oh my. Oh dear. I've been keeping a cog warm all week!",
                  "g:Here, take it, dears. And come back when my real babies hatch!"]},
  "levels": [
   level("hollow-1", "Egg Hatch", "eggRescue", ["multiplication"], 6,
         ["m:Look at all these eggs, Otter. They're about to hatch!",
          "o:Answer the sums and they'll pop open!",
          "m:Gently. They're only babies."],
         ["o:Baby dinosaurs! They think I'm their mum.", "m:You do have the right hair."],
         "pet-pip", "Hatch the baby dinosaurs"),
   level("hollow-2", "Fern Dash", "dinoDash", ["multiplication"], 8,
         ["g:HONK! Who's that sniffing round my nest?",
          "o:Run, Mosey! Pick the path with the right answer!",
          "m:Right answers make us faster. Go, go, go!"],
         ["o:We lost her! I think.", "m:She's gone back to sit on something shiny."],
         "hat-goggles", "Dash through the ferns"),
   level("hollow-3", "Stepping Stones", "bridgeBuilder", ["multiplication", "sequences"], 6,
         ["m:This stream is too fast to swim, even for me.",
          "o:Then we'll hop across on the stones with the right numbers!",
          "m:Count carefully. Splashing is not a plan."],
         ["o:Dry feet! Well, mostly."],
         "deco-campfire", "Hop across the stream"),
   level("hollow-4", "Tiptoe Past", "tiptoe", ["multiplication", "missingNumber"], 8,
         ["o:Shh! Mama Maia is fast asleep on her nest.",
          "m:And look what she's sitting on. Our Cog!",
          "o:Each right answer is one tiptoe closer. Quietly!"],
         ["m:She's sitting right on top of it.", "o:Then we'll have to be brave. And quick."],
         "pet-nubbin", "Sneak past a sleeping dinosaur"),
   level("hollow-5", "Mama Maia", "guardian", ["multiplication", "missingNumber"], 9,
         ["g:HONK! You again! Stay away from my shiny egg!",
          "o:It's not an egg! It's part of our time machine!",
          "m:Answer quickly, Otter. Here she comes!"],
         ["o:One part back. Five to go!", "m:And not a single egg was harmed."],
         None, "Escape Mama Maia and win back the Cog"),
  ]},
 {"id": "meadow", "name": "Three-Horn Meadow", "tagline": "Long grass and one grumpy triceratops", "focus": "",
  "colour": "#F2A13C", "roar": 2, "part": "spring", "partName": "Spring", "ready": False,
  "guardian": {"name": "Trevor", "kind": "trevor", "phases": ["g:Coming soon!"] * 3, "befriended": ["g:Coming soon!"]},
  "levels": coming_soon("meadow", [("dinoDash", ["multiplication"]), ("eggRescue", ["multiplication", "missingNumber", "wordProblems"]),
                                   ("tiptoe", ["multiplication", "missingNumber"]), ("bridgeBuilder", ["multiplication", "sequences"]),
                                   ("guardian", ["multiplication", "missingNumber", "wordProblems"])],
                        ["pet-chomp", "hat-leaf", "deco-flowers", "pet-butterfly"])},
 {"id": "swamp", "name": "Spiky Swamp", "tagline": "Muddy water and one spiky tail", "focus": "",
  "colour": "#3FA796", "roar": 3, "part": "propeller", "partName": "Propeller", "ready": False,
  "guardian": {"name": "Steggy", "kind": "steggy", "phases": ["g:Coming soon!"] * 3, "befriended": ["g:Coming soon!"]},
  "levels": coming_soon("swamp", [("mathsSplash", ["multiplication", "missingNumber"]), ("bridgeBuilder", ["multiplication", "sequences"]),
                                  ("eggRescue", ["multiplication", "missingNumber", "wordProblems"]), ("mathsSplash", ["multiplication", "missingNumber"]),
                                  ("guardian", ["multiplication", "missingNumber", "wordProblems"])],
                        ["pet-turtle", "hat-pirate", "deco-mushroom", "pet-crab"])},
 {"id": "peaks", "name": "Pterodactyl Peaks", "tagline": "High rocks and sneaky thieves", "focus": "",
  "colour": "#8FA8FF", "roar": 4, "part": "bell", "partName": "Bell", "ready": False,
  "guardian": {"name": "The Swoop Squad", "kind": "swoop", "phases": ["g:Coming soon!"] * 3, "befriended": ["g:Coming soon!"]},
  "levels": coming_soon("peaks", [("dinoDash", ["multiplication", "missingNumber"]), ("tiptoe", ["multiplication", "missingNumber", "wordProblems"]),
                                  ("bridgeBuilder", ["multiplication", "sequences"]), ("eggRescue", ["multiplication", "missingNumber", "wordProblems"]),
                                  ("guardian", ["multiplication", "missingNumber", "wordProblems"])],
                        ["pet-owl", "hat-shades", "deco-kite", "pet-firefly"])},
 {"id": "ridge", "name": "Raptor Ridge", "tagline": "Hot rocks and a clever pack", "focus": "",
  "colour": "#E8643C", "roar": 5, "part": "dial", "partName": "Dial", "ready": False,
  "guardian": {"name": "The Snatch Pack", "kind": "raptors", "phases": ["g:Coming soon!"] * 3, "befriended": ["g:Coming soon!"]},
  "levels": coming_soon("ridge", [("dinoDash", ["division", "multiplication"]), ("eggRescue", ["division", "missingNumber"]),
                                  ("bridgeBuilder", ["division", "sequences"]), ("tiptoe", ["division", "multiplication"]),
                                  ("guardian", ["division", "missingNumber", "wordProblems"])],
                        ["pet-cinder", "hat-crown", "deco-lantern", "pet-ember"])},
 {"id": "rex", "name": "T-Rex Territory", "tagline": "The biggest, loudest dinosaur of all", "focus": "",
  "colour": "#9B5BD6", "roar": 6, "part": "core", "partName": "Times Core", "ready": False,
  "guardian": {"name": "Rex", "kind": "rex", "phases": ["g:Coming soon!"] * 3, "befriended": ["g:Coming soon!"]},
  "levels": coming_soon("rex", [("dinoDash", ["multiplication", "division", "missingNumber"]), ("tiptoe", ["multiplication", "missingNumber", "division", "wordProblems"]),
                                ("bridgeBuilder", ["multiplication", "division", "sequences"]), ("eggRescue", ["multiplication", "missingNumber", "division", "wordProblems"]),
                                ("guardian", ["multiplication", "missingNumber", "division", "wordProblems"])],
                        ["pet-comet", "hat-wizard", "deco-rainbow", "pet-moonmoth"])},
]

# The opening story, on Rainbow Island. The practice round winds up the Times Machine.
INTRO = [
    "n:One sunny morning on Rainbow Island…",
    "o:Ta-da! Mosey, meet the Tick-Tock Times Machine!",
    "m:Otter, it's a bathtub.",
    "o:A bathtub that travels through time! It runs on times tables.",
    "m:Could it take us back to the dinosaurs? Mosasaurs swam in the sea back then.",
    "o:Your great-great-great… great-grandma! Answer three sums to wind it up!",
]
# After the practice round: back in time, the crash, and a roar.
INTRO_AFTER = [
    "n:Whoosh! Back, back, back… sixty-six million years!",
    "n:CLANG! The Times Machine crash-landed and burst into six pieces!",
    "m:Otter, the parts flew off in every direction.",
    "o:No parts, no machine. No machine, no way home!",
    "n:Then, not very far away, something very big went ROAR.",
    "m:That was a T-Rex.",
    "o:How do you know?",
    "m:Because it's a lot closer now.",
    "o:Let's find those parts. Quickly!",
]
# When a child keeps getting answers wrong, Otter or Mosey kindly suggests asking a grown-up.
ASK_GROWN_UP = [
    "o:Hey, don't worry! Why don't you ask a grown-up for some help?",
    "m:This one's a bit tricky. How about asking a grown-up to help us?",
    "o:You're trying really hard! Shall we get a grown-up to help with this one?",
    "m:Even the best explorers ask for help. Why don't you find a grown-up?",
]
# The Fix-It Workshop at Crash Camp, after each Big Escape.
WORKSHOP = {
    "intro": ["o:Back to Crash Camp! Time to fit the part.",
              "m:Every bolt has to go in just the right place. Let's count carefully."],
    "done": ["o:It fits! Listen to it tick!",
             "m:One step closer to home."],
}
# The finale, once all six parts are home. Written properly in M4; recorded only when every zone is ready.
FINALE = {
    "opening": ["n:The six parts are back where they belong…", "n:The Times Machine is whole again!", "n:Every dinosaur came to say goodbye!"],
    "guardians": {z: "g:Coming soon!" for z in ["hollow", "meadow", "swamp", "peaks", "ridge", "rex"]},
    "thanks": ["o:We couldn't have done any of this without you!",
               "m:All those times tables, and you never gave up!",
               "o:Three cheers for our champion! Hip hip…"],
    "photo": ["m:Everyone squeeze in for a photo! Say cheese!"],
    "countdown": ["o:Three!", "o:Two!", "o:One!"],
    "after": ["o:Every zone's open now, so you can play any level again, whenever you like!",
              "m:And there are still trophies hiding out there, and stars to win, and pets to find!"],
}
