import { readFileSync, writeFileSync, mkdtempSync, rmdirSync, unlinkSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/opening_cinematic');
const output = process.argv[2];
if (!output || !path.isAbsolute(output) || !output.endsWith('.mp4')) {
  throw new Error('Provide an absolute .mp4 output path outside the game assets.');
}
if (output.startsWith(root + path.sep)) throw new Error('Export review movies outside runtime assets.');
const sandbox = {};
vm.runInNewContext(readFileSync(path.join(root, 'review-data.js'), 'utf8'), sandbox);
const data = sandbox.OPENING_REVIEW;
const temp = mkdtempSync(path.join(path.dirname(output), '.opening-animatic-export-'));
const generated = [];
const run = args => execFileSync('ffmpeg', ['-hide_banner', '-v', 'warning', '-y', ...args], { stdio: 'inherit' });
function time(seconds) {
  const centiseconds = Math.round(seconds * 100);
  return `${Math.floor(centiseconds / 360000)}:${String(Math.floor(centiseconds / 6000) % 60).padStart(2,'0')}:${String(Math.floor(centiseconds / 100) % 60).padStart(2,'0')}.${String(centiseconds % 100).padStart(2,'0')}`;
}
try {
  for (const image of new Set(data.shots.map(shot => shot.image))) {
    const png = path.join(temp, image.replace('.svg', '.png'));
    generated.push(png);
    run(['-i', path.join(root, image), '-frames:v', '1', '-update', '1', png]);
  }
  const captions = path.join(temp, 'captions.ass');
  generated.push(captions);
  let ass = `[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,DejaVu Sans,23,&H00E6E6E6,&H000000FF,&H00100803,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,125,125,90,1
Style: Label,DejaVu Sans,12,&H00BDAF9E,&H000000FF,&H00100803,&H80000000,0,0,0,0,100,100,1,0,1,1,0,7,30,30,24,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
`;
  for (const shot of data.shots) {
    ass += `Dialogue: 0,${time(shot.at)},${time(shot.at + shot.duration)},Label,,0,0,0,,${shot.label} / ANIMATIC\n`;
  }
  for (const line of data.lines) {
    const text = line.text.replaceAll('\\', '\\\\').replaceAll('{', '\\{').replaceAll('}', '\\}');
    ass += `Dialogue: 1,${time(line.at)},${time(line.at + line.seconds)},Default,,0,0,0,,{\\fs14\\c&H90C9F5&}${line.speaker}\\N{\\fs23\\c&HE6E6E6&}${text}\n`;
  }
  writeFileSync(captions, ass);
  const args = [], filters = [], fps = 24;
  for (let i = 0; i < data.shots.length; i++) {
    const shot = data.shots[i], duration = shot.duration + (i < data.shots.length-1 ? 1.1 : 0);
    args.push('-i', path.join(temp, shot.image.replace('.svg', '.png')));
    const u = `min(1,on/${shot.duration * fps})`;
    const ease = `(${u}*${u}*(3-2*${u}))`;
    const z = `${shot.from[0]}+${shot.to[0] - shot.from[0]}*${ease}`;
    const x = `iw*(1-1/zoom)*(${shot.from[1]}/100+${(shot.to[1]-shot.from[1])/100}*${ease})`;
    const y = `ih*(1-1/zoom)*(${shot.from[2]}/100+${(shot.to[2]-shot.from[2])/100}*${ease})`;
    filters.push(`[${i}:v]scale=2560:1440,zoompan=z='${z}':x='${x}':y='${y}':d=${Math.ceil(duration * fps)}:s=1280x720:fps=${fps},format=yuv420p,settb=AVTB[v${i}]`);
  }
  let video = 'v0';
  for (let i = 1; i < data.shots.length; i++) {
    filters.push(`[${video}][v${i}]xfade=transition=fade:duration=1.1:offset=${data.shots[i].at}[mix${i}]`);
    video = `mix${i}`;
  }
  const safeCaptions = captions.replaceAll('\\','/').replaceAll(':','\\:').replaceAll("'", "'\\''");
  filters.push(`[${video}]drawbox=x=0:y=0:w=iw:h=65:color=0x03060a:t=fill,drawbox=x=0:y=ih-65:w=iw:h=65:color=0x03060a:t=fill,ass=filename='${safeCaptions}'[picture]`);
  for (let i = 0; i < data.lines.length; i++) {
    const line = data.lines[i];
    args.push('-i', path.join(root, line.audio));
    filters.push(`[${data.shots.length+i}:a]adelay=${Math.round(line.at*1000)}:all=1[a${i}]`);
  }
  filters.push(`${data.lines.map((_,i)=>`[a${i}]`).join('')}amix=inputs=${data.lines.length}:normalize=0,volume=0.9,alimiter=limit=0.95:level=0,apad,atrim=duration=${data.duration}[dialogue]`);
  console.log(`EXPORTING: ${data.duration}s / 1280x720 / ${fps} fps / twenty voice clips`);
  run([...args, '-filter_complex_threads', '2', '-filter_complex', filters.join(';'),
    '-map','[picture]','-map','[dialogue]','-t',String(data.duration),
    '-c:v','libx264','-preset','fast','-crf','20','-threads','2',
    '-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',output]);
  console.log('EXPORTED: ' + output);
} finally {
  for (const file of generated) if (existsSync(file)) unlinkSync(file);
  rmdirSync(temp);
}
