class_name AvatarInteractionController
extends Node

@export var interact_action: StringName = &"interact"
@export var interaction_range: float = 2.5
@export var auto_close_extra_range: float = 0.4

var avatar: Avatar
var _active_loot_npc_id: int = -1


func _ready() -> void:
	avatar = get_parent() as Avatar


func _process(_delta: float) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		if _active_loot_npc_id > 0:
			_close_loot_view()
		_set_interaction_prompt_visible(false)
		return

	var nearby_npc: TestNpc = _find_nearest_lootable_npc(maxf(interaction_range, 0.1))
	_update_prompt_for_npc(nearby_npc)

	if Input.is_action_just_pressed(String(interact_action)):
		_toggle_interaction()

	if _active_loot_npc_id > 0:
		_refresh_active_target()


func request_loot_transfer(npc_id: int, from_slot: int, preferred_to_slot: int = -1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if npc_id <= 0:
		return
	if from_slot < 0:
		return

	if multiplayer.is_server():
		_server_try_loot_transfer(avatar.player_id, npc_id, from_slot, preferred_to_slot)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_loot_transfer.rpc_id(host_id, npc_id, from_slot, preferred_to_slot)


func _toggle_interaction() -> void:
	if _active_loot_npc_id > 0:
		_close_loot_view()
		return

	var nearest_npc: TestNpc = _find_nearest_lootable_npc(maxf(interaction_range, 0.1))
	if nearest_npc == null:
		return
	_open_loot_view_for_npc(nearest_npc)


func _refresh_active_target() -> void:
	var npc: TestNpc = _find_npc_by_id(_active_loot_npc_id)
	if npc == null:
		_close_loot_view()
		return
	if not npc.can_be_looted_by(avatar.player_id, interaction_range + auto_close_extra_range):
		_close_loot_view()
		return


func _open_loot_view_for_npc(npc: TestNpc) -> void:
	if avatar == null:
		return
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	if npc == null:
		return
	if npc.inventory == null:
		return

	_active_loot_npc_id = npc.npc_id
	var loot_title: String = "%s corpse" % npc.display_name
	UIManager.player_ui.open_loot_inventory_for_npc(_active_loot_npc_id, npc.inventory, loot_title)


func _close_loot_view() -> void:
	_active_loot_npc_id = -1
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	UIManager.player_ui.close_loot_inventory()


func _update_prompt_for_npc(npc: TestNpc) -> void:
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	if npc == null:
		_set_interaction_prompt_visible(false)
		return
	UIManager.player_ui.set_interaction_prompt(_build_interaction_prompt_text(npc.display_name))


func _set_interaction_prompt_visible(is_visible: bool) -> void:
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	UIManager.player_ui.set_interaction_prompt_visible(is_visible)


func _find_nearest_lootable_npc(max_distance: float) -> TestNpc:
	var nearest_npc: TestNpc = null
	var nearest_distance_sq: float = max_distance * max_distance
	var avatar_position: Vector3 = _get_avatar_interaction_position()
	var candidates: Array = get_tree().get_nodes_in_group("TestNpc")
	for candidate in candidates:
		if not (candidate is TestNpc):
			continue
		var npc: TestNpc = candidate as TestNpc
		if npc == null:
			continue
		if not npc.can_be_looted_by(avatar.player_id, max_distance):
			continue
		var distance_sq: float = avatar_position.distance_squared_to(npc.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest_distance_sq = distance_sq
		nearest_npc = npc
	return nearest_npc


func _get_avatar_interaction_position() -> Vector3:
	if avatar == null:
		return Vector3.ZERO
	if avatar.movement_body != null and is_instance_valid(avatar.movement_body):
		return avatar.movement_body.global_position
	return avatar.global_position


func _build_interaction_prompt_text(target_name: String) -> String:
	var keybind_glyph: String = _resolve_action_keybind_glyph(String(interact_action))
	return "%s Loot %s" % [keybind_glyph, target_name]


func _resolve_action_keybind_glyph(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "[E]"
	var action_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event in action_events:
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		var key_label: String = key_event.as_text_key_label().strip_edges()
		if key_label.is_empty():
			var physical_label: String = OS.get_keycode_string(key_event.physical_keycode).strip_edges()
			key_label = physical_label
		if key_label.is_empty():
			key_label = key_event.as_text().strip_edges()
		if not key_label.is_empty():
			return "[%s]" % key_label.to_upper()
	for event in action_events:
		var event_label: String = event.as_text().strip_edges()
		if not event_label.is_empty():
			return "[%s]" % event_label
	return "[E]"


func _find_npc_by_id(target_npc_id: int) -> TestNpc:
	if target_npc_id <= 0:
		return null
	var candidates: Array = get_tree().get_nodes_in_group("TestNpc")
	for candidate in candidates:
		if not (candidate is TestNpc):
			continue
		var npc: TestNpc = candidate as TestNpc
		if npc != null and npc.npc_id == target_npc_id:
			return npc
	return null


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_loot_transfer(npc_id: int, from_slot: int, preferred_to_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_loot_transfer(sender_id, npc_id, from_slot, preferred_to_slot)


func _server_try_loot_transfer(sender_id: int, npc_id: int, from_slot: int, preferred_to_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	var npc: TestNpc = _find_npc_by_id(npc_id)
	if npc == null:
		return
	npc.try_loot_transfer_to_player(sender_id, from_slot, preferred_to_slot)
