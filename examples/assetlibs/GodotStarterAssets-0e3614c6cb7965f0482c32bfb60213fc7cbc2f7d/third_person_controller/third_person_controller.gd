extends CharacterBody3D


#TODO: Smooth camera rotation.
#TODO: Closer camera when lower pitch.


@export var body_rotation_speed: float = 5

@export_group("Camera")

## Max camera pitch in degrees.
@export_range(-90, 90, 0.1, "degrees") var max_pitch: float = 10

## Min camera pitch in degrees.
@export_range(-90, 90, 0.1, "degrees") var min_pitch: float = -90

## Lenght of the spring arm.
@export var camera_distance: float = 5

## How quickly the camera gimbal follows the target position.
@export var camera_follow_speed: float = 25

@export_subgroup("Mouse", "mouse_")

## If true, the mouse will be captured after clicking on the screen. [br][br]
## Capturing the mouse is recommended in order to get raw input.
@export var mouse_capture_on_click = true

## Camera mouse sensitivity.
@export_range(0.1, 10, 0.05, "or_greater") var mouse_sensitivity: float = 5

@export_subgroup("joystick", "joystick_")

## Camera gamepad sensitivity.
@export_range(0.1, 10, 0.01, "or_greater") var joystick_sensitivity: float = PI

## Exponent to which the joystick input will be raised to.[br][br]
## Smaller values are more reactive, while bigger ones allow for finer move when the tilting is subtle.
@export_exp_easing("positive_only") var joystick_exp: float = 2

@export_group("Movement")

## Player  walk speed.
@export var walk_speed: float = 5

## Player run speed.
@export var run_speed: float = 7.5

## Player acceleration towards the target velocity.
@export var ground_acceleration: float = 10

## Player air acceleration towards the target velocity while airborne.
@export var air_acceleration: float = 0.5

## Jump speed.
@export var jump_speed: float = 5


# The position to which the camera will interpolate.
@onready var camera_position: Marker3D = get_node("CameraPosition")

# The camera nodes.
@onready var camera_gimbal: Node3D = get_node("CameraGimbal")
@onready var camera_yaw: Node3D = camera_gimbal.get_node("Yaw")
@onready var camera_pitch: Node3D = camera_gimbal.get_node("Yaw/Pitch")
@onready var camera_arm: SpringArm3D = camera_gimbal.get_node("Yaw/Pitch/SpringArm")
@onready var camera: Camera3D = camera_gimbal.get_node("Yaw/Pitch/SpringArm/Camera")

#Container node for the body mesh.
@onready var body: Node3D = get_node("Body")

func _unhandled_input(event)->void:
	# Mouse capture and release.
	if mouse_capture_on_click:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	
		if event is InputEventKey:
			if event.is_action_pressed("ui_cancel"):
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
	
	# Mouse look.
	if event is InputEventMouseMotion:
		mouse_look(event)


func _ready() -> void:
	initialize_body()
	initialize_camera()


func _process(delta: float) -> void:
	joystick_look(delta)
	update_camera_transform(delta)
	update_body_transform(delta)


func _physics_process(delta: float) -> void:
	move(delta)


# Prepares the camera for manual physics interpolation.
func initialize_camera()-> void:
	camera_arm.spring_length = camera_distance
	camera_arm.add_excluded_object(get_rid())
	camera_gimbal.top_level = true
	camera_gimbal.set_physics_interpolation_mode(PHYSICS_INTERPOLATION_MODE_OFF)


# Prepares the body for manual physics interpolation.
func initialize_body()-> void:
	body.top_level = true
	body.set_physics_interpolation_mode(PHYSICS_INTERPOLATION_MODE_OFF)


# Updates the camera transform using interpolation if enabled.
func update_camera_transform(delta)-> void:
	var target_position: Vector3
	
	# Follow the standard transform if physics interpolation is disabled.
	if !get_tree().physics_interpolation:
		target_position = camera_position.global_transform.origin
	
	# Follow the interpolated origin.
	else:
		target_position = camera_position.get_global_transform_interpolated().origin
	
	# Interpolate the camera gimbal towards the target position.
	camera_gimbal.global_position = target_position + (camera_gimbal.global_position - target_position) * exp(-camera_follow_speed * delta)


func update_body_transform(delta: float):
	# Update body origin normally if physics interpolation is disabled.
	if !get_tree().physics_interpolation:
		body.global_transform.origin = global_transform.origin
	
	# Use the interpolated origin.
	else:
		body.global_transform.origin = get_global_transform_interpolated().origin
	
	# Rotate the body towards velocity direction.
	var horizontal_velocity: Vector3 = velocity - velocity.project(Vector3.UP)
	
	# Are we moving?
	if horizontal_velocity.is_zero_approx():
		return
	
	# Interpolate towards the velocity direction scaling by speed.
	var current_direction: Vector3 = -body.global_basis.z
	var target_direction: Vector3 = horizontal_velocity.normalized()
	var from_to: Quaternion = Quaternion(Vector3.UP, current_direction.signed_angle_to(target_direction, Vector3.UP))
	var target_rotation: Quaternion = body.quaternion * from_to
	var t = 1 - exp(-body_rotation_speed * horizontal_velocity.length() * delta)
	
	# Apply the new rotation.
	body.quaternion = body.quaternion.slerp(target_rotation, t)
	
	# Orthonormalize to prevent degradation.
	body.orthonormalize()


# Handles movement.
func move(delta: float)-> void:
	# Ground acceleration by default.
	var accel: float = ground_acceleration
	
	# Are we running?
	var target_speed: float = walk_speed if !Input.is_action_pressed("run") else run_speed
	
	# Are we grounded?.
	if !is_on_floor():
		
		# Apply gravity.
		velocity += get_gravity() * delta
		
		# Change to air acceleration.
		accel = air_acceleration
	
	# Jump.
	elif Input.is_action_just_pressed("jump"):
		velocity += Vector3.UP * jump_speed - velocity.project(Vector3.UP)
	
	# Wish velocity.
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var wish_direction: Vector3 = camera_yaw.global_basis.orthonormalized() * Vector3(input_vector.x, 0, -input_vector.y)
	var wish_velocity: Vector3 = wish_direction * target_speed 
	
	# Decompose the velocity to prevent friction from affecting gravity.
	var vertical_velocity: Vector3 = velocity.project(Vector3.UP)
	var horizontal_velocity: Vector3 = velocity - vertical_velocity
	
	# Are we close enough?
	if horizontal_velocity.distance_to(wish_velocity) <= 0.001:
		horizontal_velocity = wish_velocity
	
	# Exponential decay towards target velocity.
	else:
		horizontal_velocity = wish_velocity + (horizontal_velocity - wish_velocity) * exp(-accel * delta)
	
	# Recompose the velocity.
	velocity = horizontal_velocity + vertical_velocity
	
	# Move the character.
	move_and_slide()


# Handles aim look with the mouse.
func mouse_look(event: InputEventMouseMotion)-> void:
	var motion: Vector2 = event.screen_relative
	
	# Assuming a standard DPI (dots per inch) of 1000, scale the motion to be
	# 1 radian per inch. Prevents mouse_sensitivity from needed tiny values.
	motion /= 1000
	
	# Multiply by mouse sensitivity.
	motion *= mouse_sensitivity
	
	# Rotate the camera.
	add_yaw(motion.x)
	add_pitch(motion.y)
	clamp_pitch()


# Handles aim look with the gamepad.
func joystick_look(delta) -> void:
	var motion: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_down", "camera_up")
	
	# Calculate the response curve.
	if joystick_exp != 1:
		motion = motion.normalized() * pow(motion.length(), joystick_exp)
	
	# multiply by joystick sensitivity.
	motion *= joystick_sensitivity
	
	# Multiply by delta.
	motion *= delta
	
	# Rotate the camera.
	add_yaw(motion.x)
	add_pitch(-motion.y)
	clamp_pitch()


# Adds yaw.
func add_yaw(amount)->void:
	if is_zero_approx(amount):
		return
	
	camera_yaw.rotate_object_local(Vector3.DOWN, amount)
	camera_yaw.orthonormalize()


# Adds pitch.
func add_pitch(amount)->void:
	if is_zero_approx(amount):
		return
	
	camera_pitch.rotate_object_local(Vector3.LEFT, amount)
	camera_pitch.orthonormalize()


# Clamps the pitch between min_pitch and max_pitch.
func clamp_pitch()->void:
	
	if camera_pitch.rotation.x > deg_to_rad(min_pitch) and camera_pitch.rotation.x < deg_to_rad(max_pitch):
		return
	
	camera_pitch.rotation.x = clamp(camera_pitch.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	camera_pitch.orthonormalize()
