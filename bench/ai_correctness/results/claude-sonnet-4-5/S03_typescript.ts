const str = "mississippi";
let count = 0;

for (let i = 0; i < str.length; i++) {
  if (str[i] === 's') {
    count++;
  }
}

console.log(count);