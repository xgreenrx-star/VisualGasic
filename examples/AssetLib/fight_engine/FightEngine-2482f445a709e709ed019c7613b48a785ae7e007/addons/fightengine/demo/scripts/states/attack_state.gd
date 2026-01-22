extends LimboState

@export var anim_player: AnimationPlayer
@export var anim_name: StringName
@export var friction: float = 1000

var input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	anim_player.animation_finished.connect(_on_finished)

func _enter() -> void:
	anim_player.play(anim_name)

func _update(delta: float) -> void:
	var velocity: Vector2 = agent.velocity as Vector2
	if velocity.x != 0:
		agent.velocity.x = move_toward(agent.velocity.x, 0, friction * delta)

func _exit() -> void:
	anim_name = ""

func _on_finished(name: StringName) -> void:
	dispatch(EVENT_FINISHED)
