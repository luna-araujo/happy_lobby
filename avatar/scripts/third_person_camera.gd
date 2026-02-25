class_name ThirdPersonCamera
extends Node3D

@export var sensitivity: float = 0.005
@export var distance: float = 7.5
@export var height_offset: float = 1.6
@export var min_pitch_degrees: float = -45.0
@export var max_pitch_degrees: float = 60.0
@export var capture_mouse_on_ready: bool = true
@export var target_path: NodePath

@onready var anchor: Node3D = $Anchor
@onready var camera_3d: Camera3D = $Anchor/Camera3D

var _yaw: float = 0.0
var _pitch: float = 0.0
var target: Node3D


func _ready() -> void:
	if not target_path.is_empty():
		set_target(get_node_or_null(target_path) as Node3D)

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


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position


func _input(event: InputEvent) -> void:
	if not is_current():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * sensitivity
		_pitch -= motion.relative.y * sensitivity
		_pitch = clampf(
			_pitch,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		rotation.y = _yaw
		anchor.rotation.x = _pitch

	if event.is_action_pressed("camera_release"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _update_camera_distance() -> void:
	camera_3d.position = Vector3(0.0, height_offset, distance)


func set_target(new_target: Node3D) -> void:
	target = new_target
	if is_instance_valid(target):
		global_position = target.global_position


func is_current() -> bool:
	return camera_3d.is_current()


func make_current() -> void:
	camera_3d.make_current()
	if capture_mouse_on_ready:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
