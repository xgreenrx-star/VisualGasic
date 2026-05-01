const sentence = "the quick brown fox jumps over the lazy dog the";
const wordCounts: { [word: string]: number } = {};

sentence.split(' ').forEach(word => {
  if (word) {
    wordCounts[word] = (wordCounts[word] || 0) + 1;
  }
});

console.log(JSON.stringify(wordCounts, null, 2));