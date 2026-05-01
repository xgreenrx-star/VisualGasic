const csv = "name,age\nAlice,30\nBob,25\nCarol,42";

const lines = csv.split('\n');
let totalAge = 0;
let count = 0;

for (let i = 1; i < lines.length; i++) {
    const parts = lines[i].split(',');
    if (parts.length === 2) {
        const age = parseInt(parts[1], 10);
        if (!isNaN(age)) {
            totalAge += age;
            count++;
        }
    }
}

const averageAge = count > 0 ? totalAge / count : 0;
console.log(averageAge);