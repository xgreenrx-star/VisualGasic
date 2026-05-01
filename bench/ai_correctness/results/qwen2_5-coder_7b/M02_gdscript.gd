extends SceneTree

func _init():
    var primes = []
    for num in range(2, 51):
        if is_prime(num):
            primes.append(str(num))
    print(",".join(primes))
    quit()

func is_prime(n: int) -> bool:
    if n <= 1:
        return false
    for i in range(2, int(n ** 0.5) + 1):
        if n % i == 0:
            return false
    return true