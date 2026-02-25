class_name ColorPickerOption
extends HBoxContainer

signal value_changed(new_color: Color)

@export var option_id: String = ""
var color_picker: ColorPickerButton


func _ready() -> void:
	color_picker = $ColorPickerButton

	var target: Node = get_node_or_null("%Avatar")
	if not target:
		target = get_node_or_null("%Char")
	if target:
		sync_from_target(target)

	color_picker.color_changed.connect(_on_color_changed)


func sync_from_character(character: Node) -> void:
	sync_from_target(character)


func sync_from_target(target: Node) -> void:
	if not target or option_id == "":
		return
	if not target.has_method("get_material"):
		return

	var char_shader := target.call("get_material") as ShaderMaterial
	if not char_shader:
		return

	var current_color = char_shader.get_shader_parameter(option_id)
	if typeof(current_color) == TYPE_COLOR:
		color_picker.color = current_color
		return

	var shader := char_shader.shader
	if not shader:
		return

	for uniform in shader.get_shader_uniform_list():
		if uniform is Dictionary and uniform.get("name", "") == option_id:
			var default_value = uniform.get("default_value", null)
			if typeof(default_value) == TYPE_COLOR:
				color_picker.color = default_value
			return


func _on_color_changed(new_color: Color) -> void:
	value_changed.emit(new_color)
