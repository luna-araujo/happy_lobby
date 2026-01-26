class_name HeightOption
extends HBoxContainer

signal value_changed(new_height: float)

var slider: HSlider

func _ready() -> void:
	slider = $HSlider
	slider.value_changed.connect(func(value: float):
		value_changed.emit(value)
	)
