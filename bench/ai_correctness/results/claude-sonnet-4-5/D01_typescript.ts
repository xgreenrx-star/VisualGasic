const prices: { [key: string]: number } = {
  apple: 0.5,
  bread: 2.25,
  cheese: 5.99
};

for (const key in prices) {
  console.log(`${key}: ${prices[key]}`);
}

const total = Object.values(prices).reduce((sum, value) => sum + value, 0);
console.log(`Total: ${total}`);