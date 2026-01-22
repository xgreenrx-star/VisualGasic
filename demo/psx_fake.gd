extends Node

var pixel_size = 4
var dithering = 1
var saturation = 1.0
var mode = 0

func SetParam(name, value):
	if name == "pixel_size":
		pixel_size = value
	elif name == "dithering":
		dithering = value
	elif name == "saturation":
		saturation = value
	elif name == "mode":
		mode = value
	print("PSXBridge: SetParam " + name + " = " + str(value))
