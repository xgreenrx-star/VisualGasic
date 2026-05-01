def is_prime(num):
    if num <= 1:
        return False
    for i in range(2, int(num**0.5) + 1):
        if num % i == 0:
            return False
    return True

if __name__ == '__main__':
    primes = [str(num) for num in range(2, 51) if is_prime(num)]
    print(','.join(primes))