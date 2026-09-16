extends Node

# GDScript mirror of demo/bench.vg's BenchCall/BenchCallHelper, for an
# apples-to-apples function-call cost comparison vs VisualGasic. Same nested
# loop, same per-iteration call, same Long (int) arithmetic.

func BenchCallHelper(x: int) -> int:
	return x + 1

func BenchCall(iterations: int, inner: int) -> int:
	var s: int = 0
	for i in range(iterations):
		for j in range(inner):
			s = BenchCallHelper(s)
	return s
