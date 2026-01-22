extends Node

func RequestVelocity(tx, ty, tz, speed):
	# Simple stub: compute normalized vector from origin to target scaled by speed
	var dir = Vector3(tx, ty, tz)
	if dir.length() == 0:
		print("BallisticBridge: requested zero-length target")
		return
	dir = dir.normalized() * speed
	print("BallisticBridge: RequestVelocity -> " + str(dir))
	return dir