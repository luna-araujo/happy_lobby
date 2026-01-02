class_name IncrementalOption
extends HBoxContainer

signal incremented(new_value:int)
signal decremented(new_value:int)
signal value_changed(new_value:int)

var min_index := 0
var max_index := 4
var current_index := 0

@onready var minus_button:Button = $MinusButton
@onready var plus_button:Button = $PlusButton
@onready var title_label:Label = $TitleLabel
@onready var options_label:Label = $OptionsLabel

func _ready() -> void:
	minus_button.pressed.connect(_minus_pressed)
	plus_button.pressed.connect(_plus_pressed)
	_update_options_label()

func _minus_pressed():
	if (current_index - 1 >= min_index):
		current_index -= 1
		decremented.emit(current_index)
		value_changed.emit(current_index)
		_update_options_label()

func _plus_pressed():
	if (current_index + 1 < max_index):
		current_index += 1
		incremented.emit(current_index)
		value_changed.emit(current_index)
		_update_options_label()

func setup(name, array):
	title_label.text = name
	_set_max_index_by_arr_size(array)
	_update_options_label()

func _update_options_label():
	options_label.text = "%s/%s" % [str(current_index + 1), str(max_index)]

func set_index(idx:int, silent:bool):
	current_index = idx
	_update_options_label()
	if silent: return
	value_changed.emit(current_index)

func _set_max_index_by_arr_size(arr):
	if arr is Array:
		min_index = 0
		max_index = arr.size()
