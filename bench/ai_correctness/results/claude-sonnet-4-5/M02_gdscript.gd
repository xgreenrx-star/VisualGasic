extends SceneTree

func _init():
    var primes = []
    for num in range(2, 51):
        var is_prime = true
        for i in range(2, int(sqrt(num)) + 1):
            if num % i == 0:
                is_prime = false
                break
        if is_prime:
            primes.append(str(num))
    print(",".join(primes))
    quit()