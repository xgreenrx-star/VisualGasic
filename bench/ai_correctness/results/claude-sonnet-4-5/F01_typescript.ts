import * as fs from 'fs';

const lines = ['Line 1', 'Line 2', 'Line 3'];
const content = lines.join('\n');

fs.writeFileSync('output.txt', content, 'utf-8');

const readContent = fs.readFileSync('output.txt', 'utf-8');
const readLines = readContent.split('\n');

readLines.forEach((line, index) => {
  console.log(`${index + 1}: ${line}`);
});