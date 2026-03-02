class_name HealVfx
extends Node3D

@export var pulse_duration: float = 0.45
@export var rise_height: float = 1.1
@export var start_scale: float = 0.4
@export var end_scale: float = 1.35

@onready var _heal_ring: Node3D = $HealRing
@onready var _heal_light: OmniLight3D = $HealLight


func _ready() -> void:
	if _heal_ring != null:
		_heal_ring.scale = Vector3.ONE * start_scale
	_start_pulse()


func _start_pulse() -> void:
	var duration: float = maxf(pulse_duration, 0.05)
	var pulse_tween: Tween = create_tween()
	pulse_tween.set_trans(Tween.TRANS_QUAD)
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(self, "position:y", position.y + rise_height, duration)
	if _heal_ring != null:
		pulse_tween.parallel().tween_property(_heal_ring, "scale", Vector3.ONE * end_scale, duration)
	if _heal_light != null:
		pulse_tween.parallel().tween_property(_heal_light, "light_energy", 0.0, duration)
	pulse_tween.finished.connect(_on_pulse_finished)


func _on_pulse_finished() -> void:
	queue_free()
