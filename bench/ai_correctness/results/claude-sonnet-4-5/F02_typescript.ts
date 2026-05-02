const csvString = "name,age\nAlice,30\nBob,25\nCarol,42";

const lines = csvString.split("\n");
const header = lines[0].split(",");
const ageIndex = header.indexOf("age");

let sum = 0;
let count = 0;

for (let i = 1; i < lines.length; i++) {
  const values = lines[i].split(",");
  const age = parseInt(values[ageIndex], 10);
  sum += age;
  count++;
}

const average = sum / count;
console.log(average);