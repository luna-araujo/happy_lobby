class_name ThirdPersonCamera
extends Node3D

@export var sensitivity: float = 0.005
@export var distance: float = 7.5
@export var height_offset: float = 1.6
@export var min_pitch_degrees: float = -45.0
@export var max_pitch_degrees: float = 60.0
@export var capture_mouse_on_ready: bool = true
@export var target_path: NodePath
@export var gun_controller_path: NodePath = NodePath("../GunController")
@export var aim_fov_reduction_percent: float = 15.0
@export var aim_fov_lerp_speed: float = 14.0

@onready var anchor: Node3D = $Anchor
@onready var camera_3d: Camera3D = $Anchor/Camera3D

var _yaw: float = 0.0
var _pitch: float = 0.0
var _default_fov: float = 90.0
var target: Node3D
var avatar: Avatar
var gun_controller: AvatarGunController


func _ready() -> void:
	if not target_path.is_empty():
		set_target(get_node_or_null(target_path) as Node3D)
	avatar = get_parent() as Avatar
	gun_controller = get_node_or_null(gun_controller_path) as AvatarGunController
	_default_fov = camera_3d.fov

	_yaw = rotation.y
	_pitch = anchor.rotation.x
	_pitch = clampf(
		_pitch,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	anchor.rotation.x = _pitch

	# Ensure the camera always uses a neutral local rotation.
	camera_3d.basis = Basis.IDENTITY
	_update_camera_distance()


func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position
	_update_aim_fov(delta)


func _input(event: InputEvent) -> void:
	if not is_current():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= motion.relative.x * sensitivity
		_pitch -= motion.relative.y * sensitivity
		_pitch = clampf(
			_pitch,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		rotation.y = _yaw
		anchor.rotation.x = _pitch



func _update_camera_distance() -> void:
	camera_3d.position = Vector3(0.0, height_offset, distance)


func _update_aim_fov(delta: float) -> void:
	if not is_current():
		camera_3d.fov = _default_fov
		return
	if avatar == null:
		camera_3d.fov = _default_fov
		return
	if gun_controller == null:
		gun_controller = get_node_or_null(gun_controller_path) as AvatarGunController
	if gun_controller == null:
		camera_3d.fov = _default_fov
		return
	var is_aiming_with_gun: bool = avatar._is_local_controlled() and gun_controller.is_gun_equipped() and gun_controller.is_aiming()
	var reduction_ratio: float = clampf(aim_fov_reduction_percent / 100.0, 0.0, 0.95)
	var target_fov: float = _default_fov
	if is_aiming_with_gun:
		target_fov = _default_fov * (1.0 - reduction_ratio)
	camera_3d.fov = lerpf(camera_3d.fov, target_fov, clampf(aim_fov_lerp_speed * delta, 0.0, 1.0))


func set_target(new_target: Node3D) -> void:
	target = new_target
	if is_instance_valid(target):
		global_position = target.global_position


func is_current() -> bool:
	return camera_3d.is_current()


func set_active(active: bool) -> void:
	if active:
		make_current()
		return

	camera_3d.current = false
	if capture_mouse_on_ready and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if UIManager != null:
			UIManager.release_mouse()


func make_current() -> void:
	camera_3d.make_current()
	if capture_mouse_on_ready:
		if UIManager != null:
			UIManager.capture_mouse()
