extends Label

@export var limbo_hsm: LimboHSM

var setter = func(new: LimboState, old: LimboState):
	text = new.name

func _ready() -> void:
	limbo_hsm.active_state_changed.connect(setter)
