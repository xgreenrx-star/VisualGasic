extends Node

var beam_length = 0.0
var beam_color = 0

func SetParam(name, value):
	if name == "beam_length":
		beam_length = value
	elif name == "beam_color":
		beam_color = value
	print("LaserBridge: SetParam " + name + " = " + str(value))

func Fire():
	print("LaserBridge: Fire - length=" + str(beam_length) + " color=" + str(beam_color))
