const array = [3, 1, 4, 1, 5, 9, 2, 6];
let sum = 0;

for (const num of array) {
    sum += num;
}

const average = sum / array.length;

console.log(`Sum: ${sum}, Average: ${average}`);