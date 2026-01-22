extends Node

var _params = {}

func SetParam(name, value):
	_params[name] = value
	print("ProceduralBridge: SetParam " + name + " = " + str(value))

func Regenerate():
	print("ProceduralBridge: Regenerate called")
