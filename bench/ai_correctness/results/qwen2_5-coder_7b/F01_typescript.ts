import * as fs from 'fs';

const lines = ["Line 1", "Line 2", "Line 3"];
const filePath = 'output.txt';

// Write lines to file
lines.forEach((line, index) => {
    fs.appendFileSync(filePath, line + '\n');
});

// Read and print each line with its line number
fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) throw err;
    const lines = data.split('\n').filter(line => line.trim() !== '');
    lines.forEach((line, index) => {
        console.log(`${index + 1}: ${line}`);
    });
});