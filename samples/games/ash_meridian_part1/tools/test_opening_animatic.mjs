import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/opening_cinematic');
const script = JSON.parse(readFileSync(path.join(root, 'script.json'), 'utf8'));
const voices = JSON.parse(readFileSync(path.join(root, 'voices.json'), 'utf8'));
const sandbox = {};
vm.runInNewContext(readFileSync(path.join(root, 'review-data.js'), 'utf8'), sandbox);
const review = sandbox.OPENING_REVIEW;
const timeline = JSON.parse(readFileSync(path.join(root, 'timeline.json'), 'utf8'));
const envelopes = JSON.parse(readFileSync(path.join(root, 'speech-envelope.json'), 'utf8'));

test('mouth motion derives from the exact clips rather than time-based random chatter', () => {
  const end = timeline.shots.find(shot => shot.id === 'departure').at;
  const barLines = timeline.lines.filter(line => line.at < end);
  assert.equal(Object.keys(envelopes).length, barLines.length);
  for (const line of barLines) {
    const envelope = envelopes[line.id];
    const file = path.join(root, line.audio);
    assert.equal(envelope.text, line.text);
    assert.equal(envelope.sha256, createHash('sha256').update(readFileSync(file)).digest('hex'));
    assert.equal(envelope.hz, 50);
    assert.equal(envelope.samples.length, Math.ceil(line.seconds * 50));
    assert.ok(envelope.samples.every(value => Number.isFinite(value) && value >= 0 && value <= 1));
    const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', file, '-ac', '1',
      '-ar', '16000', '-f', 'f32le', 'pipe:1']);
    const rms = frame => {
      frame = Math.max(0, Math.min(envelope.samples.length - 1, frame));
      let sum = 0, count = 0;
      for (let i = frame * 320; i < (frame + 1) * 320 && i * 4 < raw.length; i++) {
        sum += raw.readFloatLE(i * 4) ** 2;
        count++;
      }
      return Math.min(1, Math.max(0, (Math.sqrt(sum / Math.max(1, count)) - .008) * 9));
    };
    for (const index of [0, Math.floor(envelope.samples.length / 2), envelope.samples.length - 1]) {
      const expected = rms(index - 1) * .2 + rms(index) * .6 + rms(index + 1) * .2;
      assert.ok(Math.abs(envelope.samples[index] - expected) < .000051, `Stale waveform sample ${line.id}/${index}`);
    }
  }
});

test('Godot and browser share exactly the same measured edit', () => {
  const expected = JSON.parse(JSON.stringify(review));
  expected.lines = expected.lines.map(({ source, ...line }) => line);
  assert.deepEqual(timeline, expected);
});

test('opening is a two-to-three-minute, seven-shot review, not a campaign replacement', () => {
  assert.equal(review.shots.length, 7);
  assert.ok(review.duration >= 120 && review.duration <= 180);
  assert.match(review.status, /not the live campaign/);
  assert.match(review.markVoice, /Recast Mark distinctly/);
  let end = 0;
  for (const shot of review.shots) {
    assert.ok(Math.abs(shot.at - end) < .02, `Gap before ${shot.id}`);
    assert.ok(shot.duration > 0);
    assert.ok(existsSync(path.join(root, shot.image)));
    assert.ok(shot.from[0] >= 1 && shot.to[0] >= 1);
    end = shot.at + shot.duration;
  }
  assert.ok(Math.abs(end - review.duration) < .02);
});

test('every line has exact matching neural speech, a real measured clip and an offline source', () => {
  assert.equal(review.lines.length, 20);
  assert.equal(voices.length, 20);
  assert.equal(new Set(review.lines.map(line => line.id)).size, 20);
  for (const line of review.lines) {
    const source = script.lines.find(candidate => candidate.id === line.id);
    assert.equal(source.text, line.text);
    assert.equal(source.speaker, line.speaker);
    assert.equal(source.profile, line.profile);
    assert.equal(source.speed, line.speed);
    assert.equal(source.silence, line.silence);
    assert.equal(line.backend, 'kokoro');
    const clip = readFileSync(path.join(root, line.audio));
    assert.equal(clip.subarray(0, 4).toString(), 'OggS');
    assert.equal(Buffer.from(line.source.split(',')[1], 'base64').compare(clip), 0);
    const measured = Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries',
      'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', path.join(root, line.audio)],
      { encoding: 'utf8' }).trim());
    assert.ok(Math.abs(measured - line.seconds) < .01, `Stale duration ${line.id}`);
    assert.ok(line.seconds > .2);
  }
});

test('speech does not overlap or get cut by a shot boundary', () => {
  let end = 0;
  for (const line of review.lines) {
    const shot = review.shots.find(shot => shot.id === line.shot);
    assert.ok(line.at >= end - .02, `Overlapping line ${line.id}`);
    assert.ok(line.at >= shot.at);
    assert.ok(line.at + line.seconds <= shot.at + shot.duration + .02);
    end = line.at + line.seconds + line.gap;
  }
});

test('story keeps the wager, warning, Stacy and the existing stash directions', () => {
  const text = script.lines.map(line => line.text).join(' ');
  assert.match(text, /You won.*send the coordinates/i);
  assert.match(text, /Don't go there/);
  assert.match(text, /I'm done.*don't have it in me anymore/i);
  assert.doesNotMatch(text, /scaveng/i);
  assert.match(text, /Stacy and I/);
  assert.match(text, /east of the yard road/);
  assert.match(text, /broken amber marker by the drain/i);
  assert.match(text, /not going back/);
  assert.match(text, /if it feels wrong, you leave.*Right away/i);
  assert.doesNotMatch(text, /empty windows|offensively good|quite the same thing/i);
  assert.doesNotMatch(text, /quarantine|Rob is|MJH|M\.J\.H\./i);
  for (const line of script.lines) {
    if (line.speaker === 'JASON') assert.equal(line.profile, 'JASON');
    if (line.speaker === 'ORAC') assert.equal(line.profile, 'ORAC');
  }
});

test('four original keyframes have valid vector roots and no remote dependencies', () => {
  const images = new Set(review.shots.map(shot => shot.image));
  assert.equal(images.size, 4);
  for (const image of images) {
    const svg = readFileSync(path.join(root, image), 'utf8');
    assert.match(svg, /^<svg xmlns="http:\/\/www.w3.org\/2000\/svg"/);
    assert.match(svg, /viewBox="0 0 1600 900"/);
    assert.match(svg, /<\/svg>\s*$/);
    assert.doesNotMatch(svg, /(?:href|src)="https?:/);
  }
});

test('ship and ring artwork use the provisional physical scale', () => {
  const glb = readFileSync(path.join(root, '../black_channel/models/ash_flight.glb'));
  const jsonLength = glb.readUInt32LE(12);
  const model = JSON.parse(glb.toString('utf8', 20, 20 + jsonLength));
  const positions = model.meshes.flatMap(mesh => mesh.primitives
    .map(primitive => model.accessors[primitive.attributes.POSITION]));
  const bounds = [0, 1, 2].map(axis => ({
    min: Math.min(...positions.map(accessor => accessor.min[axis])),
    max: Math.max(...positions.map(accessor => accessor.max[axis])),
  }));
  const scale = script.visualScale;
  assert.ok(Math.abs((bounds[0].max - bounds[0].min) - scale.ashWingspanM) < .01);
  assert.ok(Math.abs((bounds[2].max - bounds[2].min) - scale.ashLengthM) < .02);
  assert.equal(scale.ringOuterRadiusKm / scale.ringInnerRadiusKm, 4 / 3);
  assert.ok(scale.planetRadiusKm < scale.ringInnerRadiusKm);

  const projected = (angle, width, length) => {
    const radians = angle * Math.PI / 180;
    return Math.cos(radians) * width + Math.sin(radians) * length;
  };
  const artScale = (image, x, y, angle) => {
    const svg = readFileSync(path.join(root, image), 'utf8');
    const transform = svg.match(new RegExp(`translate\\(${x} ${y}\\) rotate\\(${angle}\\) scale\\(([\\d.]+)\\)`));
    assert.ok(transform, `Missing scaled ship in ${image}`);
    return Number(transform[1]);
  };
  const arrivalScale = artScale('arrival.svg', 382, 704, 26);
  const arrivalWidthPx = 1132
    * projected(26, scale.ashWingspanM, scale.ashLengthM)
    / (scale.ringOuterRadiusKm * 2000)
    * (scale.arrivalCameraToRingKm * 1000 / scale.arrivalCameraToAshM);
  assert.ok(Math.abs(arrivalScale - arrivalWidthPx / projected(26, 296, 260)) < .0001);
  assert.ok(arrivalWidthPx / 1132 < .03, 'Ash stays a small silhouette against the full ring');

  const approachScale = artScale('approach.svg', 775, 612, 42);
  const approachWidthPx = 152 * projected(42, scale.ashWingspanM, scale.ashLengthM)
    / scale.serviceOpeningClearWidthM;
  assert.ok(Math.abs(approachScale - approachWidthPx / projected(42, 296, 260)) < .0001);
  assert.ok(approachWidthPx < 152, 'Ash fits within the approach opening with clearance');

  const shader = readFileSync(path.join(root, '../../shaders/opening_ring_study.gdshader'), 'utf8');
  const shaderRadius = name => Number(shader.match(new RegExp(`const float ${name} = ([\\d.]+);`))?.[1]);
  const modelUnitsPerKm = shaderRadius('RING_OUTER_RADIUS') / scale.ringOuterRadiusKm;
  assert.ok(Math.abs(shaderRadius('PLANET_RADIUS') / modelUnitsPerKm - scale.planetRadiusKm) < 1);
  assert.ok(Math.abs(shaderRadius('RING_INNER_RADIUS') / modelUnitsPerKm - scale.ringInnerRadiusKm) < 1);
});
