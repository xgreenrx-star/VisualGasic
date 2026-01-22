extends Node

var _params = {}

func SetParam(name, value):
	_params[name] = value
	print("HorrorBridge: SetParam " + name + " = " + str(value))

func Regenerate():
	print("HorrorBridge: Regenerate called")
