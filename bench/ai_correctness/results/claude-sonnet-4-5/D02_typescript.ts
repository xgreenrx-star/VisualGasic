const sentence = "the quick brown fox jumps over the lazy dog the";
const words = sentence.toLowerCase().split(" ");
const wordCounts = new Map<string, number>();

for (const word of words) {
  if (word) {
    wordCounts.set(word, (wordCounts.get(word) || 0) + 1);
  }
}

for (const [word, count] of wordCounts) {
  console.log(`${word}: ${count}`);
}