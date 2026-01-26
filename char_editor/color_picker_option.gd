class_name ColorPickerOption
extends HBoxContainer

signal value_changed(new_color: Color)

@export var option_id: String = ""
var color_picker: ColorPickerButton


func _ready() -> void:
	color_picker = $ColorPickerButton
	color_picker.color_changed.connect(_on_color_changed)


func _on_color_changed(new_color: Color) -> void:
	value_changed.emit(new_color)
