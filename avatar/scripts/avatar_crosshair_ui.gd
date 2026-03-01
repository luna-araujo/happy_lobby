class_name AvatarCrosshairUi
extends CanvasLayer

@export var gun_controller_path: NodePath = NodePath("../GunController")
@export var color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var arm_length: float = 12.0
@export var arm_thickness: float = 2.0
@export var arm_gap: float = 5.0
@export var dot_size: float = 2.0

var avatar: Avatar
var gun_controller: AvatarGunController
var _root: Control
var _crosshair_center: Control


func _ready() -> void:
	layer = 110
	avatar = get_parent() as Avatar
	gun_controller = get_node_or_null(gun_controller_path) as AvatarGunController
	_build_ui()
	_update_visibility()


func _process(_delta: float) -> void:
	_update_visibility()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "CrosshairRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_crosshair_center = Control.new()
	_crosshair_center.name = "CrosshairCenter"
	_crosshair_center.size = Vector2(1.0, 1.0)
	_crosshair_center.anchor_left = 0.5
	_crosshair_center.anchor_top = 0.5
	_crosshair_center.anchor_right = 0.5
	_crosshair_center.anchor_bottom = 0.5
	_crosshair_center.offset_left = -0.5
	_crosshair_center.offset_top = -0.5
	_crosshair_center.offset_right = 0.5
	_crosshair_center.offset_bottom = 0.5
	_crosshair_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair_center)

	_add_arm(Vector2(-arm_gap - arm_length, -arm_thickness * 0.5), Vector2(arm_length, arm_thickness))
	_add_arm(Vector2(arm_gap, -arm_thickness * 0.5), Vector2(arm_length, arm_thickness))
	_add_arm(Vector2(-arm_thickness * 0.5, -arm_gap - arm_length), Vector2(arm_thickness, arm_length))
	_add_arm(Vector2(-arm_thickness * 0.5, arm_gap), Vector2(arm_thickness, arm_length))
	_add_arm(Vector2(-dot_size * 0.5, -dot_size * 0.5), Vector2(dot_size, dot_size))


func _add_arm(offset: Vector2, size: Vector2) -> void:
	var arm: ColorRect = ColorRect.new()
	arm.color = color
	arm.position = offset
	arm.size = size
	arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_center.add_child(arm)


func _update_visibility() -> void:
	if _root == null:
		return
	if avatar == null:
		_root.visible = false
		return
	if not avatar._is_local_controlled():
		_root.visible = false
		return
	if gun_controller == null:
		gun_controller = get_node_or_null(gun_controller_path) as AvatarGunController
	if gun_controller == null:
		_root.visible = false
		return
	_root.visible = gun_controller.is_gun_equipped()
