extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_box: HitBox2D = $Sprite2D/HitBox
@onready var hurt_box: HurtBox2D = $Sprite2D/HurtBox

@onready var hsm: LimboHSM = $LimboHSM
@onready var idle_state: LimboState = $LimboHSM/Idle
@onready var move_state: LimboState = $LimboHSM/Move
@onready var attack_state: LimboState = $LimboHSM/Attack

var input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	_init_state_machine()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("z"):
		var cur_state = hsm.get_active_state()
		var anim = "moves/"+_get_move_id("z")
		if not anim_player.has_animation(anim): return
		attack_state.anim_name = anim
		cur_state.dispatch("attack")
	elif event.is_action_pressed("x"):
		var cur_state = hsm.get_active_state()
		var anim = "moves/"+_get_move_id("x")
		if not anim_player.has_animation(anim): return
		attack_state.anim_name = anim
		cur_state.dispatch("attack")
	elif event.is_action_pressed("c"):
		var cur_state = hsm.get_active_state()
		var anim = "moves/"+_get_move_id("c")
		if not anim_player.has_animation(anim): return
		attack_state.anim_name = anim
		cur_state.dispatch("attack")
		

func _process(delta: float) -> void:
	flip_sprite()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, gravity, gravity * delta)
	
	move_and_slide()

func _init_state_machine() -> void:
	hsm.add_transition(idle_state, move_state, idle_state.EVENT_FINISHED)
	hsm.add_transition(move_state, idle_state, move_state.EVENT_FINISHED)
	hsm.add_transition(idle_state, attack_state, "attack")
	hsm.add_transition(move_state, attack_state, "attack")
	hsm.add_transition(attack_state, idle_state, attack_state.EVENT_FINISHED)
	
	hsm.initialize(self)
	hsm.set_active(true)
	
	hsm.initial_state = idle_state

func flip_sprite() -> void:
	if velocity.x < 0:
		sprite.scale.x = -1
	elif velocity.x > 0:
		sprite.scale.x = 1

func _get_move_id(action: String) -> StringName:
	var direction_name: String = "neutral"
	match input_vector:
		Vector2.LEFT:
			direction_name = "left"
		Vector2.RIGHT:
			direction_name = "right"
		Vector2.UP:
			direction_name = "up"
		Vector2.DOWN:
			direction_name = "down"
	
	var move_id = &"{direction}_{action}".format({"direction": direction_name, "action": action})
	return move_id
