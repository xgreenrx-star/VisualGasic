function fibonacci(n: number): number[] {
  const result: number[] = [];
  let a = 0;
  let b = 1;
  
  for (let i = 0; i < n; i++) {
    result.push(a);
    const temp = a + b;
    a = b;
    b = temp;
  }
  
  return result;
}

const fibNumbers = fibonacci(10);
fibNumbers.forEach(num => console.log(num));