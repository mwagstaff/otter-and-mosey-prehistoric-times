// A short audio test for the Campfire Sing-Along (docs/PLAN.md, section 14): the first four lines
// of the 3s, Otter calling and Mosey answering, over a composed campfire beat, at the three round
// speeds, in two deliveries (rhythmic chant and half-sung). Nothing is bundled with the app.
//
//   cd tools/sfx && node --env-file=../../.env.local singalong-test.mjs           # compose/record what's missing, then mix
//   node --env-file=../../.env.local singalong-test.mjs --mix                     # mix again from what's recorded
//
// Output goes to the git-ignored samples/singalong-test. Mixing uses singalong-render.swift.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "samples/singalong-test");
const clips = join(out, "clips");
mkdirSync(clips, { recursive: true });
const voices = JSON.parse(readFileSync(join(here, "narration.config.json"), "utf8"));
const crack = join(here, "../../PrehistoricTimes/Resources/Audio/crack.m4a");
const mixOnly = process.argv.includes("--mix");
const client = mixOnly ? null : new ElevenLabsClient();

const words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];
const table = 3;
const lines = [1, 2, 3, 4];
const deliveries = {
  chant: { otter: "[excited, chanting rhythmically] ", mosey: "[chanting rhythmically, cheerful] " },
  sung: { otter: "[singing cheerfully] ", mosey: "[singing, happy] " },
};
const sourceBpm = 100;
const rounds = [{ bpm: 88, mode: "together" }, { bpm: 100, mode: "finish" }, { bpm: 112, mode: "whole" }];

// 1. The beat.
const beat = join(out, "beat.mp3");
if (!mixOnly && !existsSync(beat)) {
  console.log("composing the test beat (30s)");
  const audio = await client.music.compose({
    prompt: "Bouncy campfire stomp for a children's times-tables sing-along with friendly dinosaurs. Steady four-on-the-floor log drum and hand-clap backbeat, plucky ukulele chords, marimba and a bouncy tuba bass on every beat. Exactly 100 bpm, strict tempo, 4/4, C major. Starts on the beat straight away. Even loudness throughout, no intro build-up, no breakdown, no ending. Instrumental: no vocals, no spoken words.",
    musicLengthMs: 30000,
    modelId: "music_v2_5",
    forceInstrumental: true,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(beat, Buffer.concat(chunks));
}

// 2. The voices.
async function say(who, text, file) {
  if (mixOnly || existsSync(file)) return;
  const character = voices.characters[who];
  const audio = await client.textToSpeech.convert(character.voiceId, {
    text, modelId: voices.modelId, outputFormat: voices.outputFormat, languageCode: "en", voiceSettings: character.voiceSettings,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(file, Buffer.concat(chunks));
  console.log(`recorded ${file.split("/").pop()}: ${text}`);
}
const clip = (delivery, kind, n) => join(clips, `${delivery}_${kind}_${n}.mp3`);
for (const [delivery, tags] of Object.entries(deliveries)) {
  for (const n of lines) {
    const call = `${words[n][0].toUpperCase()}${words[n].slice(1)} times ${words[table]} is…`;
    await say("otter", tags.otter + call, clip(delivery, "q", n));
    await say("mosey", tags.mosey + `${words[n * table]}!`, clip(delivery, "a", n));
  }
}

// 3. Find the beat: an onset envelope, autocorrelated for the tempo, then the phase of the beats
// and which beat starts the bar.
function decode(file, rate) {
  const wav = join(out, "analysis.wav");
  execFileSync("afconvert", ["-f", "WAVE", "-d", `LEF32@${rate}`, "-c", "1", file, wav]);
  const data = readFileSync(wav);
  const at = data.indexOf("data") + 8;
  return new Float32Array(data.buffer.slice(data.byteOffset + at, data.byteOffset + at + Math.floor((data.length - at) / 4) * 4));
}
const rate = 11025, hop = 64, fps = rate / hop;
const pcm = decode(beat, rate);
const energy = [];
for (let i = 0; i + hop <= pcm.length; i += hop) {
  let sum = 0;
  for (let j = 0; j < hop; j++) sum += pcm[i + j] * pcm[i + j];
  energy.push(Math.log(1e-6 + sum));
}
const onset = energy.map((value, i) => (i ? Math.max(0, value - energy[i - 1]) : 0));
let best = { score: -1, period: 0 };
for (let bpm = 80; bpm <= 130; bpm += 0.05) {
  const period = (60 / bpm) * fps;
  let score = 0;
  for (let i = 0; i + 4 * period < onset.length; i++) {
    const lag = (k) => onset[Math.round(i + k * period)];
    score += onset[i] * (lag(1) + lag(2) + lag(4));
  }
  if (score > best.score) best = { score, period, bpm };
}
const period = best.period;
let phase = 0, phaseScore = -1;
for (let p = 0; p < period; p += 0.25) {
  let score = 0;
  for (let t = p; t < onset.length; t += period) score += onset[Math.round(t)] + 0.5 * (onset[Math.round(t) + 1] ?? 0);
  if (score > phaseScore) { phaseScore = score; phase = p; }
}
let barBeat = 0, barScore = -1;
for (let b = 0; b < 4; b++) {
  let score = 0;
  for (let t = phase + b * period; t < onset.length; t += 4 * period) score += onset[Math.round(t)];
  if (score > barScore) { barScore = score; barBeat = b; }
}
const beatSeconds = period / fps;
let firstDownbeat = (phase + barBeat * period) / fps;
console.log(`beat: ${best.bpm.toFixed(2)} bpm (asked for ${sourceBpm}), first downbeat at ${firstDownbeat.toFixed(3)}s`);

// 4. Mix with AVAudioEngine (singalong-render.swift), the same engine the game would use: the beat
// through a time-pitch unit for each round's speed, each voice clip scheduled at an exact sample time.
const plan = {
  beat, crack, out, beatSeconds, firstDownbeat, detectedBpm: best.bpm, rounds,
  deliveries: Object.fromEntries(Object.keys(deliveries).map((d) => [d, {
    calls: lines.map((n) => clip(d, "q", n)), answers: lines.map((n) => clip(d, "a", n)),
  }])),
};
writeFileSync(join(out, "plan.json"), JSON.stringify(plan, null, 2));
execFileSync("swift", [join(here, "singalong-render.swift"), join(out, "plan.json")], { stdio: "inherit" });
for (const delivery of Object.keys(deliveries)) {
  const wav = join(out, `singalong-test-${delivery}.wav`);
  execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "160000", wav, wav.replace(/\.wav$/, ".m4a")]);
  console.log(`made ${wav.replace(/\.wav$/, ".m4a")}`);
}
if (!mixOnly) {
  const usage = await client.user.subscription.get();
  console.log(`credits used: ${usage.characterCount} of ${usage.characterLimit}`);
}
