class_name CharCustomizeOption
extends IncrementalOption


@export var title: String = "Option"
@export var modified_polygons: Array[String]


func _ready() -> void:
	super()
	var template_option := _resolve_options(modified_polygons[0] if modified_polygons.size() > 0 else "")
	setup(title, template_option)


func setup(name, array):
	title_label.text = name
	_set_max_index_by_arr_size(array)
	_update_options_label()


func _update_options_label():
	options_label.text = "%s/%s" % [str(current_index + 1), str(max_index)]


func _set_max_index_by_arr_size(arr):
	if arr is Array:
		min_index = 0
		max_index = arr.size()


func _resolve_options(option_name: String) -> Array:
	if option_name.is_empty():
		return []
	if get_node_or_null("%Avatar"):
		return AvatarEditor.get_customization_options(option_name)
	return CharEditor.get_customization_options(option_name)
