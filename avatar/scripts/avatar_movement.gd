class_name AvatarMovement
extends CharacterBody3D


@export var move_speed: float = 11.0
@export var acceleration: float = 48.0
@export var deceleration: float = 56.0
@export var jump_velocity: float = 5.5
@export var fall_gravity_multiplier: float = 2.2
@export var jump_cut_multiplier: float = 0.45
@export var turn_speed: float = 18.0


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Add the gravity.
	if not is_on_floor():
		var gravity_scale := fall_gravity_multiplier if velocity.y <= 0.0 else 1.0
		velocity += get_gravity() * gravity_scale * delta

		# Releasing jump early cuts upward momentum for a snappier hop.
		if Input.is_action_just_released("move_jump") and velocity.y > 0.0:
			velocity.y *= jump_cut_multiplier

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = jump_velocity

	# Camera-relative movement on the horizon plane.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var camera := get_viewport().get_camera_3d()
	var cam_forward := Vector3.FORWARD
	var cam_right := Vector3.RIGHT
	if camera:
		cam_forward = -camera.global_transform.basis.z
		cam_right = camera.global_transform.basis.x
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	var move_direction := (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()
	var target_velocity := move_direction * move_speed
	var accel := acceleration if input_dir.length() > 0.0 else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	# Character faces camera yaw only.
	if cam_forward.length_squared() > 0.0:
		var target_yaw := atan2(-cam_forward.x, -cam_forward.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	if move_direction.length_squared() > 0.0:
		# Optional: slight extra yaw nudge while moving for responsive feel.
		var move_yaw := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, move_yaw, turn_speed * 0.35 * delta)

	move_and_slide()
