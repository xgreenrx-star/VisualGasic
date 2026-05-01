function isPrime(num: number): boolean {
    if (num <= 1) return false;
    for (let i = 2; i * i <= num; i++) {
        if (num % i === 0) return false;
    }
    return true;
}

const primes: number[] = [];
for (let i = 2; i <= 50; i++) {
    if (isPrime(i)) {
        primes.push(i);
    }
}
console.log(primes.join(','));