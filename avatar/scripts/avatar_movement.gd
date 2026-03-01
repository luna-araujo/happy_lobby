class_name AvatarMovement
extends CharacterBody3D

signal movement_updated(horizontal_speed: float)

@export var move_speed: float = 11.0
@export var acceleration: float = 48.0
@export var deceleration: float = 56.0
@export var parry_deceleration: float = 72.0
@export var air_acceleration: float = 12.0
@export var jump_height: float = 1.8
@export var jump_speed_multiplier: float = 1.25
@export var fall_gravity_multiplier: float = 2.2
@export var turn_speed: float = 18.0
@export var facing_offset_degrees: float = 0.0
@export var combat_path: NodePath = NodePath("../CharacterCombat")
@export var heavy_melee_impulse_strength: float = 10.0

var combat: CharacterCombat


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _get_jump_velocity() -> float:
	var gravity_strength := get_gravity().length()
	if gravity_strength <= 0.0:
		gravity_strength = 9.8
	var jump_gravity: float = gravity_strength * maxf(jump_speed_multiplier, 0.01)
	return sqrt(2.0 * jump_gravity * maxf(jump_height, 0.0))


func _ready() -> void:
	combat = get_node_or_null(combat_path) as CharacterCombat


func _is_movement_locked_by_combat() -> bool:
	if combat == null:
		return false
	return combat.state == CharacterCombat.CombatState.PARRYING \
		or combat.state == CharacterCombat.CombatState.STUNNED \
		or combat.state == CharacterCombat.CombatState.DEAD \
		or combat.is_melee_state()


func _is_heavy_melee_active() -> bool:
	return combat != null and combat.state == CharacterCombat.CombatState.HEAVY_MELEE


func apply_heavy_melee_impulse_from_camera(amount: float = -1.0) -> void:
	if not is_multiplayer_authority():
		return

	var camera := get_viewport().get_camera_3d()
	var cam_forward := Vector3.FORWARD
	if camera:
		cam_forward = -camera.global_transform.basis.z
	cam_forward.y = 0.0
	if cam_forward.length_squared() <= 0.0:
		return
	cam_forward = cam_forward.normalized()

	var impulse_amount := heavy_melee_impulse_strength if amount < 0.0 else amount
	velocity.x += cam_forward.x * impulse_amount
	velocity.z += cam_forward.z * impulse_amount


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var movement_locked := _is_movement_locked_by_combat()

	# Add the gravity.
	if not is_on_floor():
		var jump_speed_scale: float = maxf(jump_speed_multiplier, 0.01)
		var gravity_scale := jump_speed_scale * (fall_gravity_multiplier if velocity.y <= 0.0 else 1.0)
		velocity += get_gravity() * gravity_scale * delta

	# Handle jump.
	if not movement_locked and Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = _get_jump_velocity()

	# Camera-relative movement on the horizon plane.
	var input_dir := Vector2.ZERO if movement_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")

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
	var has_input := input_dir.length() > 0.0
	if movement_locked and is_on_floor():
		# While combat-locked on the ground, block movement input and bleed horizontal momentum.
		velocity.x = move_toward(velocity.x, 0.0, parry_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, parry_deceleration * delta)
	elif is_on_floor():
		var accel := acceleration if has_input else deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)
	else:
		# Keep horizontal momentum in air; only steer when directional input exists.
		var air_accel := air_acceleration if has_input else 0.0
		velocity.x = move_toward(velocity.x, target_velocity.x, air_accel * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, air_accel * delta)

	# Character faces movement direction.
	var facing_offset_radians := deg_to_rad(facing_offset_degrees)
	if _is_heavy_melee_active() and cam_forward.length_squared() > 0.0:
		var heavy_target_yaw := atan2(-cam_forward.x, -cam_forward.z) + facing_offset_radians
		rotation.y = lerp_angle(rotation.y, heavy_target_yaw, turn_speed * delta)
	elif move_direction.length_squared() > 0.0:
		var move_yaw := atan2(-move_direction.x, -move_direction.z) + facing_offset_radians
		rotation.y = lerp_angle(rotation.y, move_yaw, turn_speed * delta)

	move_and_slide()
	movement_updated.emit(get_horizontal_speed())
