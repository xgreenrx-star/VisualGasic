const prices: { [key: string]: number } = {
    "apple": 0.5,
    "bread": 2.25,
    "cheese": 5.99
};

let total = 0;

for (const key in prices) {
    if (prices.hasOwnProperty(key)) {
        console.log(`${key}: ${prices[key]}`);
        total += prices[key];
    }
}

console.log(`Total: ${total}`);