extends IncrementalOption
class_name CharCustomizeOption

@export var title: String = "Option"
@export var modified_polygons: Array[String] = []

func _ready() -> void:
	super._ready()

	var option_name := ""
	if modified_polygons.size() > 0:
		option_name = modified_polygons[0]

	var template_option := _resolve_options(option_name)
	setup(title, template_option)

func setup(name: String, array: Array) -> void:
	title_label.text = name
	_set_max_index_by_arr_size(array)
	_update_options_label()

func _update_options_label() -> void:
	options_label.text = "%s/%s" % [str(current_index + 1), str(max_index)]

func _set_max_index_by_arr_size(arr) -> void:
	if arr is Array:
		min_index = 0
		max_index = arr.size()

func _resolve_options(option_name: String) -> Array:
	if option_name.is_empty():
		return []
	return CharEditor.get_customization_options(option_name)
