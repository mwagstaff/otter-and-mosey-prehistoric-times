// Records the Campfire Sing-Along (docs/PLAN.md, section 14) with ElevenLabs and bundles it:
// Otter's calls ("Four times three is…") for every table and multiplier from 1 to 12, Mosey's
// answers ("twelve!") for every product, and the backing loop, cut to an exact number of bars.
//
//   cd tools/sfx && npm install
//   node --env-file=../../.env.local sing.mjs            # record anything missing
//   node --env-file=../../.env.local sing.mjs --count    # what would be recorded, spending nothing
//   node --env-file=../../.env.local sing.mjs --loop     # cut the loop again from tools/sfx/raw
//
// The keys match SongPlan.callKey and SongPlan.answerKey in PrehistoricTimesCore. The delivery tags
// are the ones chosen in the audio test (singalong-test.mjs).
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const speechDir = join(here, "../../PrehistoricTimes/Resources/Speech");
const audioDir = join(here, "../../PrehistoricTimes/Resources/Audio");
const rawDir = join(here, "raw");
mkdirSync(rawDir, { recursive: true });
const voices = JSON.parse(readFileSync(join(here, "narration.config.json"), "utf8"));
const flags = new Set(process.argv.slice(2));
const client = flags.has("--count") ? null : new ElevenLabsClient();

const small = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
  "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
const tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
function words(n) {
  if (n < 20) return small[n];
  if (n < 100) return tens[Math.floor(n / 10)] + (n % 10 ? "-" + small[n % 10] : "");
  const rest = n % 100;
  return small[Math.floor(n / 100)] + " hundred" + (rest ? " and " + words(rest) : "");
}
const capital = (text) => text[0].toUpperCase() + text.slice(1);

const jobs = [];
for (let table = 1; table <= 12; table++) {
  for (let multiplier = 1; multiplier <= 12; multiplier++) {
    jobs.push({ who: "otter", key: `singq_${table}x${multiplier}`,
                text: `[excited, chanting rhythmically] ${capital(words(multiplier))} times ${words(table)} is…` });
  }
}
const answers = [...new Set(Array.from({ length: 144 }, (_, i) => (Math.floor(i / 12) + 1) * ((i % 12) + 1)))].sort((a, b) => a - b);
for (const n of answers) jobs.push({ who: "mosey", key: `singa_${n}`, text: `[chanting rhythmically, cheerful] ${words(n)}!` });

const missing = jobs.filter((job) => !existsSync(join(speechDir, `say_${job.key}.mp3`)));
console.log(`${jobs.length} clips (${answers.length} answers), ${missing.length} to record, ${missing.reduce((n, j) => n + j.text.length, 0)} characters`);
if (flags.has("--count")) process.exit(0);

async function record(job) {
  const character = voices.characters[job.who];
  const audio = await client.textToSpeech.convert(character.voiceId, {
    text: job.text, modelId: voices.modelId, outputFormat: voices.outputFormat, languageCode: "en", voiceSettings: character.voiceSettings,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(join(speechDir, `say_${job.key}.mp3`), Buffer.concat(chunks));
}

if (!flags.has("--loop")) {
  let done = 0, failed = 0;
  const queue = [...missing];
  await Promise.all(Array.from({ length: 3 }, async () => {
    for (let job = queue.shift(); job; job = queue.shift()) {
      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          await record(job);
          if (++done % 25 === 0) console.log(`${done}/${missing.length}`);
          break;
        } catch (error) {
          if (attempt === 2) { failed++; console.error(`FAILED ${job.key}: ${String(error?.message ?? error).slice(0, 160)}`); }
          else await new Promise((resolve) => setTimeout(resolve, 2500));
        }
      }
    }
  }));
  console.log(`recorded ${done}, failed ${failed}`);
}

// The backing loop: composed at 100 bpm (the one approved in the audio test is used if it is in
// raw/), then up to 16 whole bars cut from the second bar on, so the game can loop it on the beat.
const loopRaw = join(rawDir, "sing_beat.mp3");
if (!existsSync(loopRaw) && !flags.has("--loop")) {
  console.log("composing the backing loop (60s)");
  const audio = await client.music.compose({
    prompt: "Bouncy campfire stomp for a children's times-tables sing-along with friendly dinosaurs. Steady four-on-the-floor log drum and hand-clap backbeat, plucky ukulele chords, marimba and a bouncy tuba bass on every beat. Exactly 100 bpm, strict tempo, 4/4, C major. Starts on the beat straight away. Even loudness throughout, no intro build-up, no breakdown, no ending. Instrumental: no vocals, no spoken words.",
    musicLengthMs: 60000, modelId: "music_v2_5", forceInstrumental: true,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(loopRaw, Buffer.concat(chunks));
}
if (existsSync(loopRaw)) {
  const rate = 44100, bpm = 100, bars = 16;
  const wav = join(tmpdir(), "sing-beat.wav");
  execFileSync("afconvert", ["-f", "WAVE", "-d", `LEF32@${rate}`, "-c", "2", loopRaw, wav]);
  const data = readFileSync(wav);
  const at = data.indexOf("data") + 8;
  const samples = new Float32Array(data.buffer.slice(data.byteOffset + at, data.byteOffset + at + Math.floor((data.length - at) / 8) * 8));
  // Find the first downbeat from a mono onset envelope.
  const hop = 256, beatFrames = rate * 60 / bpm;
  const energy = [];
  for (let i = 0; i + hop <= samples.length / 2; i += hop) {
    let sum = 0;
    for (let j = 0; j < hop; j++) { const v = samples[(i + j) * 2] + samples[(i + j) * 2 + 1]; sum += v * v; }
    energy.push(Math.log(1e-6 + sum));
  }
  const onset = energy.map((v, i) => (i ? Math.max(0, v - energy[i - 1]) : 0));
  let best = 0, bestScore = -1;
  for (let offset = 0; offset < beatFrames * 4; offset += hop / 4) {
    let score = 0;
    for (let t = offset; t / hop < onset.length; t += beatFrames * 4) score += onset[Math.round(t / hop)] ?? 0;
    for (let t = offset; t / hop < onset.length; t += beatFrames) score += 0.4 * (onset[Math.round(t / hop)] ?? 0);
    if (score > bestScore) { bestScore = score; best = offset; }
  }
  const start = Math.round(best + beatFrames * 4);
  // As many whole bars as the piece holds, up to `bars` (the audio test's 30-second beat holds 8).
  // Whole four-bar phrases only, so the loop never jumps mid-phrase.
  const fit = Math.floor(Math.min(bars, Math.floor((samples.length / 2 - start - rate * 0.05) / (beatFrames * 4))) / 4) * 4;
  if (fit < 4) throw new Error("the composed piece is too short for the loop");
  const length = Math.round(beatFrames * 4 * fit);
  const out = new Float32Array(length * 2);
  let peak = 0;
  for (let i = 0; i < length * 2; i++) { out[i] = samples[start * 2 + i]; peak = Math.max(peak, Math.abs(out[i])); }
  // A few milliseconds blending the end into the start, so the join doesn't click.
  const fade = Math.round(rate * 0.008);
  for (let f = 0; f < fade; f++) {
    const mix = f / fade;
    for (let c = 0; c < 2; c++) {
      const i = (length - fade + f) * 2 + c;
      out[i] = out[i] * (1 - mix) + samples[(start - fade + f) * 2 + c] * mix;
    }
  }
  const gain = 0.9 / peak;
  const pcm = new Int16Array(length * 2);
  for (let i = 0; i < pcm.length; i++) pcm[i] = Math.max(-32767, Math.min(32767, Math.round(out[i] * gain * 32767)));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + pcm.byteLength, 4); header.write("WAVEfmt ", 8);
  header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
  header.writeUInt32LE(rate, 24); header.writeUInt32LE(rate * 4, 28); header.writeUInt16LE(4, 32);
  header.writeUInt16LE(16, 34); header.write("data", 36); header.writeUInt32LE(pcm.byteLength, 40);
  writeFileSync(wav, Buffer.concat([header, Buffer.from(pcm.buffer)]));
  execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "128000", wav, join(audioDir, "sing_beat.m4a")]);
  rmSync(wav);
  console.log(`sing_beat.m4a: ${fit} bars from ${(start / rate).toFixed(3)}s, ${(length / rate).toFixed(2)}s`);
}
if (client) {
  const usage = await client.user.subscription.get();
  console.log(`credits used: ${usage.characterCount} of ${usage.characterLimit}`);
}
