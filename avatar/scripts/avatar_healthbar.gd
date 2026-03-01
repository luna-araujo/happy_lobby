class_name AvatarHealthBar
extends Node3D

@export var anchor_path: NodePath = NodePath("../Armature")
@export var height_offset: float = 6.4
@export var panel_size: Vector2i = Vector2i(320, 96)
@export var world_width: float = 3.2
@export var normal_hp_color: Color = Color(0.2, 0.85, 0.2)
@export var low_hp_color: Color = Color(0.95, 0.25, 0.25)
@export var stunned_hp_color: Color = Color(0.98, 0.68, 0.18)
@export var stunned_status_color: Color = Color(1.0, 0.84, 0.35)

var _anchor: Node3D
var _viewport: SubViewport
var _name_label: Label
var _status_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _mesh_instance: MeshInstance3D
var _is_stunned: bool = false
var _current_hp: int = 100
var _max_hp: int = 100


func _ready() -> void:
	_anchor = get_node_or_null(anchor_path) as Node3D
	_build_ui()
	_build_mesh()
	set_health(100, 100)
	set_stunned(false)
	set_player_name("")


func _process(_delta: float) -> void:
	if is_instance_valid(_anchor):
		global_position = _anchor.global_position + Vector3.UP * height_offset

	var camera := get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP, true)


func set_player_name(player_name: String) -> void:
	if not is_instance_valid(_name_label):
		return
	_name_label.text = player_name


func set_health(current_hp: int, max_hp: int) -> void:
	var safe_max: int = maxi(1, max_hp)
	var safe_hp: int = clampi(current_hp, 0, safe_max)
	_max_hp = safe_max
	_current_hp = safe_hp
	visible = safe_hp > 0

	if not is_instance_valid(_hp_bar) or not is_instance_valid(_hp_label):
		return

	_hp_bar.max_value = _max_hp
	_hp_bar.value = _current_hp
	_refresh_hp_visual_style()
	_hp_label.text = "%d/%d" % [_current_hp, _max_hp]


func set_stunned(is_stunned: bool) -> void:
	_is_stunned = is_stunned
	if is_instance_valid(_status_label):
		_status_label.visible = _is_stunned
	_refresh_hp_visual_style()


func _refresh_hp_visual_style() -> void:
	if not is_instance_valid(_hp_bar):
		return
	if _is_stunned:
		_hp_bar.modulate = stunned_hp_color
		return
	var low_hp_threshold: int = int(round(_max_hp * 0.35))
	if _current_hp > low_hp_threshold:
		_hp_bar.modulate = normal_hp_color
	else:
		_hp_bar.modulate = low_hp_color


func _build_ui() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "HealthBarViewport"
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.size = panel_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(root)

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.02, 0.7)
	root.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.text = "STUNNED"
	_status_label.modulate = stunned_status_color
	_status_label.visible = false
	vbox.add_child(_status_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0.0, 20.0)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_hp_label)
	_hp_label.text = "100/100"


func _build_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "HealthBarPanel"
	var quad := QuadMesh.new()
	var aspect := float(panel_size.y) / maxf(float(panel_size.x), 1.0)
	quad.size = Vector2(world_width, world_width * aspect)
	_mesh_instance.mesh = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _viewport.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = material

	add_child(_mesh_instance)
