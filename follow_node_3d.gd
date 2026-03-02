class_name FollowNode3D
extends Marker3D

@export var target_node:Node3D

func _ready() -> void:
	pass # Replace with function body.

func _process(_delta: float) -> void:
	global_position = target_node.global_position
