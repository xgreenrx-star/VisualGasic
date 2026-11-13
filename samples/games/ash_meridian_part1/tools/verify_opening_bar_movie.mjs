import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/opening_cinematic');
const movie = process.argv[2];
assert.ok(movie && path.isAbsolute(movie), 'Provide the absolute path of the exported bar movie.');
const timeline = JSON.parse(readFileSync(path.join(root, 'timeline.json'), 'utf8'));
const end = timeline.shots.find(shot => shot.id === 'departure').at;
const lines = timeline.lines.filter(line => line.at < end);
const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_entries',
  'format=duration:stream=codec_type,width,height,r_frame_rate', '-of', 'json', movie], { encoding: 'utf8' }));
assert.ok(Math.abs(Number(probe.format.duration) - end) < .5, 'Movie must contain the complete bar edit.');
assert.ok(probe.streams.some(stream => stream.codec_type === 'video' && stream.r_frame_rate === '24/1'));
assert.ok(probe.streams.some(stream => stream.codec_type === 'audio'));
const rate = 8000;
function decode(file) {
  const buffer = execFileSync('ffmpeg', ['-v', 'error', '-xerror', '-i', file, '-vn',
    '-ac', '1', '-ar', String(rate), '-f', 'f32le', 'pipe:1'], { maxBuffer: 8 * 1024 * 1024 });
  const result = new Float32Array(buffer.length / 4);
  for (let i = 0; i < result.length; i++) result[i] = buffer.readFloatLE(i * 4);
  return result;
}
const rendered = decode(movie);
for (const line of lines) {
  const reference = decode(path.join(root, line.audio));
  const length = Math.min(6000, reference.length);
  let start = 0, energy = -1;
  for (let candidate = 0; candidate + length <= reference.length; candidate += 1000) {
    let value = 0;
    for (let i = 0; i < length; i += 4) value += reference[candidate + i] ** 2;
    if (value > energy) { start = candidate; energy = value; }
  }
  assert.ok(energy > .001, `Reference ${line.id} must not be silent.`);
  const nominal = Math.round(line.at * rate) + start;
  function correlation(offset) {
    let dot = 0, power = 0;
    for (let i = 0; i < length; i += 4) {
      const sample = rendered[nominal + offset + i] ?? 0;
      dot += reference[start + i] * sample;
      power += sample * sample;
    }
    return power > 0 ? dot / Math.sqrt(power * energy) : 0;
  }
  let best = -1, offset = 0;
  for (let candidate = -2400; candidate <= 2400; candidate++) {
    const value = correlation(candidate);
    if (value > best) { best = value; offset = candidate; }
  }
  console.log(`VOICE ${line.id}: correlation ${best.toFixed(3)}, edit offset ${(offset / rate).toFixed(4)}s`);
  assert.ok(best > .9, `Rendered line ${line.id} differs from its canonical clip (${best.toFixed(3)}).`);
  assert.ok(Math.abs(offset / rate) < .125, `Line ${line.id} drifts from its subtitle by ${offset / rate}s.`);
}
console.log(`BAR_MOVIE_VERIFIED: ${lines.length} canonical voices, complete duration, 24 fps and subtitle-timed audio.`);
