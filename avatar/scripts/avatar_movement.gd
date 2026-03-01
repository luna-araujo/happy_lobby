class_name AvatarMovement
extends CharacterBody3D

signal movement_updated(horizontal_speed: float)

@export var move_speed: float = 11.0
@export var acceleration: float = 48.0
@export var deceleration: float = 56.0
@export var parry_deceleration: float = 72.0
@export var quick_melee_deceleration: float = 24.0
@export var heavy_melee_ground_deceleration: float = 16.0
@export var air_acceleration: float = 12.0
@export var jump_height: float = 1.8
@export var jump_speed_multiplier: float = 1.25
@export var fall_gravity_multiplier: float = 2.2
@export var heavy_melee_air_gravity_multiplier: float = 0.2
@export var turn_speed: float = 18.0
@export var facing_offset_degrees: float = 0.0
@export var combat_path: NodePath = NodePath("../CharacterCombat")
@export var gun_controller_path: NodePath = NodePath("../GunController")
@export var heavy_melee_impulse_strength: float = 10.0
@export var aim_move_speed_multiplier: float = 0.8

var combat: CharacterCombat
var gun_controller: AvatarGunController


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
	gun_controller = get_node_or_null(gun_controller_path) as AvatarGunController


func _is_movement_locked_by_combat() -> bool:
	if combat == null:
		return false
	return combat.state == CharacterCombat.CombatState.PARRYING \
		or combat.state == CharacterCombat.CombatState.STUNNED \
		or combat.state == CharacterCombat.CombatState.DEAD \
		or combat.is_melee_state()


func _is_heavy_melee_active() -> bool:
	return combat != null and combat.state == CharacterCombat.CombatState.HEAVY_MELEE


func _is_quick_melee_active() -> bool:
	return combat != null and combat.state == CharacterCombat.CombatState.QUICK_MELEE


func _is_melee_active() -> bool:
	return combat != null and combat.is_melee_state()


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

	var impulse_amount: float = heavy_melee_impulse_strength if amount < 0.0 else amount
	var current_horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var redirected_speed: float = maxf(current_horizontal_speed, impulse_amount)
	velocity.x = cam_forward.x * redirected_speed
	velocity.z = cam_forward.z * redirected_speed


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var movement_locked := _is_movement_locked_by_combat()

	# Add the gravity.
	if not is_on_floor():
		var jump_speed_scale: float = maxf(jump_speed_multiplier, 0.01)
		var gravity_scale: float = jump_speed_scale * (fall_gravity_multiplier if velocity.y <= 0.0 else 1.0)
		if _is_heavy_melee_active():
			gravity_scale *= maxf(heavy_melee_air_gravity_multiplier, 0.01)
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
	var target_speed: float = move_speed
	var aiming_with_gun: bool = false
	if gun_controller != null:
		aiming_with_gun = gun_controller.is_gun_equipped() and gun_controller.is_aiming()
	if aiming_with_gun:
		target_speed *= clampf(aim_move_speed_multiplier, 0.0, 1.0)
	var target_velocity := move_direction * target_speed
	var has_input := input_dir.length() > 0.0
	if _is_quick_melee_active() and is_on_floor():
		# Light melee keeps momentum better than hard-locked combat states.
		velocity.x = move_toward(velocity.x, 0.0, quick_melee_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, quick_melee_deceleration * delta)
	elif _is_heavy_melee_active() and is_on_floor():
		# Heavy charge also keeps ground momentum, but with stronger braking than light melee.
		velocity.x = move_toward(velocity.x, 0.0, heavy_melee_ground_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, heavy_melee_ground_deceleration * delta)
	elif movement_locked and is_on_floor():
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
	var facing_offset_radians: float = deg_to_rad(facing_offset_degrees)
	if aiming_with_gun and cam_forward.length_squared() > 0.0:
		var aim_target_yaw: float = atan2(-cam_forward.x, -cam_forward.z) + facing_offset_radians
		rotation.y = lerp_angle(rotation.y, aim_target_yaw, turn_speed * delta)
	elif _is_melee_active() and cam_forward.length_squared() > 0.0:
		var melee_target_yaw: float = atan2(-cam_forward.x, -cam_forward.z) + facing_offset_radians
		rotation.y = lerp_angle(rotation.y, melee_target_yaw, turn_speed * delta)
	elif move_direction.length_squared() > 0.0:
		var move_yaw: float = atan2(-move_direction.x, -move_direction.z) + facing_offset_radians
		rotation.y = lerp_angle(rotation.y, move_yaw, turn_speed * delta)

	move_and_slide()
	movement_updated.emit(get_horizontal_speed())
