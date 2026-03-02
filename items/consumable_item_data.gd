class_name ConsumableItemData
extends ItemData

@export var heal_amount: int = 0
@export var consume_on_use: bool = true
@export var use_vfx_scene: PackedScene


func has_use_action() -> bool:
	return heal_amount > 0


func apply_to_target(target: Node) -> int:
	if target == null:
		return 0
	if not target.has_method("heal"):
		return 0
	var result: Variant = target.call("heal", heal_amount)
	if typeof(result) != TYPE_INT:
		return 0
	return maxi(int(result), 0)
