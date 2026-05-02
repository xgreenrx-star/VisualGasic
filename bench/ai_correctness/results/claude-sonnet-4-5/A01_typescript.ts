const numbers: number[] = [3, 1, 4, 1, 5, 9, 2, 6];

const sum: number = numbers.reduce((acc, num) => acc + num, 0);
const average: number = sum / numbers.length;

console.log(`Sum: ${sum}`);
console.log(`Average: ${average}`);