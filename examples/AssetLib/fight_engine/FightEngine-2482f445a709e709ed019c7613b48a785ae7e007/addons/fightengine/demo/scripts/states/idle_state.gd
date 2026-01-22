extends LimboState

@export var anim_player: AnimationPlayer
@export var anim_name: StringName
@export var friction: float = 1000

var input_vector: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

func _enter() -> void:
	anim_player.play("moves/"+anim_name)

func _update(delta: float) -> void:
	input_vector = Vector2(Input.get_axis("left","right"), Input.get_axis("down", "up"))
	velocity = agent.velocity
	
	if input_vector.x != 0:
		dispatch(EVENT_FINISHED)
	if velocity.x != 0:
		agent.velocity.x = move_toward(velocity.x, 0, friction * delta)

func _exit() -> void:
	pass
