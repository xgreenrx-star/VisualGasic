import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export function buildOpeningPerformance(root, timeline) {
  const end = timeline.shots.find(shot => shot.id === 'departure').at;
  const result = {};
  for (const line of timeline.lines.filter(line => line.at < end)) {
    const file = path.join(root, line.audio);
    const audio = execFileSync('ffmpeg', ['-v', 'error', '-i', file, '-ac', '1',
      '-ar', '16000', '-f', 'f32le', 'pipe:1'], { maxBuffer: 8 * 1024 * 1024 });
    const samples = [];
    for (let frame = 0; frame < Math.ceil(line.seconds * 50); frame++) {
      let power = 0, count = 0;
      for (let i = frame * 320; i < (frame + 1) * 320 && i * 4 < audio.length; i++) {
        power += audio.readFloatLE(i * 4) ** 2;
        count++;
      }
      samples.push(Math.min(1, Math.max(0, (Math.sqrt(power / Math.max(1, count)) - .008) * 9)));
    }
    const smoothed = samples.map((sample, i) => Number((
      (samples[i - 1] ?? sample) * .2 + sample * .6 + (samples[i + 1] ?? sample) * .2).toFixed(4)));
    result[line.id] = { text: line.text, sha256: createHash('sha256').update(readFileSync(file)).digest('hex'),
      hz: 50, samples: smoothed };
  }
  writeFileSync(path.join(root, 'speech-envelope.json'), JSON.stringify(result) + '\n');
  console.log(`PERFORMANCE_BUILT: ${Object.keys(result).length} clip-derived jaw envelopes / 50 Hz / no phoneme claims`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/opening_cinematic');
  buildOpeningPerformance(root, JSON.parse(readFileSync(path.join(root, 'timeline.json'), 'utf8')));
}
