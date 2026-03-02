extends "res://interaction/interaction_area.gd"

@export var pickup_prompt_verb: String = "Pick up"

var dropped_item: DroppedItem


func _ready() -> void:
	super._ready()
	dropped_item = get_parent() as DroppedItem
	execution_mode = ExecutionMode.SERVER_ONLY
	interaction_priority = 15
	if dropped_item != null:
		interaction_distance = maxf(dropped_item.pickup_distance, 0.1)


func can_interact(interactor: Node) -> bool:
	if not enabled:
		return false
	if dropped_item == null:
		return false
	if interactor == null:
		return false
	var interactor_avatar: Avatar = interactor.get("avatar") as Avatar
	if interactor_avatar == null:
		return false
	return dropped_item.can_be_picked_by_avatar(interactor_avatar)


func can_interact_server(interactor_avatar: Avatar, interactor_peer_id: int) -> bool:
	if not enabled:
		return false
	if dropped_item == null:
		return false
	return dropped_item.can_be_picked_by_server(interactor_avatar, interactor_peer_id)


func get_prompt_text(_interactor: Node) -> String:
	if dropped_item == null:
		return ""
	if dropped_item.quantity > 1:
		return "%s %s x%d" % [pickup_prompt_verb.strip_edges(), dropped_item.get_display_name(), dropped_item.quantity]
	return "%s %s" % [pickup_prompt_verb.strip_edges(), dropped_item.get_display_name()]


func interact_server(interactor_peer_id: int, _requested_action_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	if dropped_item == null:
		return
	dropped_item.try_pickup_to_player(interactor_peer_id)
