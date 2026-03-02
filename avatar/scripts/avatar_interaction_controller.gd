class_name AvatarInteractionController
extends Node

@export var interact_action: StringName = &"interact"
@export var interaction_range: float = 2.5
@export var auto_close_extra_range: float = 0.4

var avatar: Avatar
var _active_loot_npc_id: int = -1
var _active_loot_chest_id: int = -1


enum InteractionTargetType {
	NONE,
	NPC,
	CHEST
}


func _ready() -> void:
	avatar = get_parent() as Avatar


func _process(_delta: float) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		if _active_loot_npc_id > 0 or _active_loot_chest_id != -1:
			_close_loot_view()
		_set_interaction_prompt_visible(false)
		return

	var nearby_npc: TestNpc = _find_nearest_lootable_npc(maxf(interaction_range, 0.1))
	var nearby_chest: StorageChest = _find_nearest_accessible_chest(maxf(interaction_range, 0.1))
	_update_prompt_for_target(nearby_npc, nearby_chest)

	if Input.is_action_just_pressed(String(interact_action)):
		_toggle_interaction()

	if _active_loot_npc_id > 0 or _active_loot_chest_id != -1:
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


func request_chest_take(chest_id: int, from_slot: int, preferred_to_slot: int = -1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if chest_id <= 0:
		return
	if from_slot < 0:
		return

	if multiplayer.is_server():
		_server_try_chest_take(avatar.player_id, chest_id, from_slot, preferred_to_slot)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_chest_take.rpc_id(host_id, chest_id, from_slot, preferred_to_slot)


func request_chest_store(chest_id: int, from_player_slot: int, preferred_chest_slot: int = -1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if chest_id <= 0:
		return
	if from_player_slot < 0:
		return

	if multiplayer.is_server():
		_server_try_chest_store(avatar.player_id, chest_id, from_player_slot, preferred_chest_slot)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_chest_store.rpc_id(host_id, chest_id, from_player_slot, preferred_chest_slot)


func _toggle_interaction() -> void:
	if _active_loot_npc_id > 0 or _active_loot_chest_id != -1:
		_close_loot_view()
		return

	var nearest_npc: TestNpc = _find_nearest_lootable_npc(maxf(interaction_range, 0.1))
	var nearest_chest: StorageChest = _find_nearest_accessible_chest(maxf(interaction_range, 0.1))
	match _resolve_preferred_target(nearest_npc, nearest_chest):
		InteractionTargetType.NPC:
			_open_loot_view_for_npc(nearest_npc)
		InteractionTargetType.CHEST:
			_open_loot_view_for_chest(nearest_chest)
		_:
			pass


func _refresh_active_target() -> void:
	if _active_loot_npc_id > 0:
		var npc: TestNpc = _find_npc_by_id(_active_loot_npc_id)
		if npc == null:
			_close_loot_view()
			return
		if not npc.can_be_looted_by(avatar.player_id, interaction_range + auto_close_extra_range):
			_close_loot_view()
		return

	if _active_loot_chest_id != -1:
		var chest: StorageChest = _find_chest_by_id(_active_loot_chest_id)
		if chest == null:
			_close_loot_view()
			return
		if not _is_chest_within_local_range(chest, interaction_range + auto_close_extra_range):
			_close_loot_view()


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
	_active_loot_chest_id = -1
	var loot_title: String = "%s corpse" % npc.display_name
	UIManager.player_ui.open_loot_inventory_for_npc(_active_loot_npc_id, npc.inventory, loot_title)


func _open_loot_view_for_chest(chest: StorageChest) -> void:
	if avatar == null:
		return
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	if chest == null:
		return
	if chest.inventory == null:
		return

	_active_loot_npc_id = -1
	_active_loot_chest_id = chest.chest_id
	var chest_title: String = chest.display_name.strip_edges()
	if chest_title.is_empty():
		chest_title = "Chest"
	UIManager.player_ui.open_loot_inventory_for_chest(_active_loot_chest_id, chest.inventory, chest_title)


func _close_loot_view() -> void:
	_active_loot_npc_id = -1
	_active_loot_chest_id = -1
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	UIManager.player_ui.close_loot_inventory()


func _update_prompt_for_target(npc: TestNpc, chest: StorageChest) -> void:
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	match _resolve_preferred_target(npc, chest):
		InteractionTargetType.NPC:
			UIManager.player_ui.set_interaction_prompt(_build_interaction_prompt_text_for_npc(npc.display_name))
		InteractionTargetType.CHEST:
			var target_name: String = chest.display_name.strip_edges()
			if target_name.is_empty():
				target_name = "Chest"
			UIManager.player_ui.set_interaction_prompt(_build_interaction_prompt_text_for_chest(target_name))
		_:
			_set_interaction_prompt_visible(false)


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


func _find_nearest_accessible_chest(max_distance: float) -> StorageChest:
	var nearest_chest: StorageChest = null
	var nearest_distance_sq: float = max_distance * max_distance
	var avatar_position: Vector3 = _get_avatar_interaction_position()
	var candidates: Array = _get_chest_candidates()
	for candidate in candidates:
		if not (candidate is StorageChest):
			continue
		var chest: StorageChest = candidate as StorageChest
		if chest == null:
			continue
		if not _is_chest_within_local_range(chest, max_distance):
			continue
		var distance_sq: float = avatar_position.distance_squared_to(chest.global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest_distance_sq = distance_sq
		nearest_chest = chest
	return nearest_chest


func _resolve_preferred_target(npc: TestNpc, chest: StorageChest) -> int:
	if npc == null and chest == null:
		return InteractionTargetType.NONE
	if npc != null and chest == null:
		return InteractionTargetType.NPC
	if chest != null and npc == null:
		return InteractionTargetType.CHEST

	var avatar_position: Vector3 = _get_avatar_interaction_position()
	var npc_distance_sq: float = avatar_position.distance_squared_to(npc.global_position)
	var chest_distance_sq: float = avatar_position.distance_squared_to(chest.global_position)
	if chest_distance_sq < npc_distance_sq:
		return InteractionTargetType.CHEST
	return InteractionTargetType.NPC


func _is_chest_within_local_range(chest: StorageChest, max_distance: float) -> bool:
	if chest == null:
		return false
	if avatar == null:
		return false
	var avatar_position: Vector3 = _get_avatar_interaction_position()
	var allowed_range: float = maxf(max_distance, 0.1)
	return avatar_position.distance_to(chest.global_position) <= allowed_range


func _get_avatar_interaction_position() -> Vector3:
	if avatar == null:
		return Vector3.ZERO
	if avatar.movement_body != null and is_instance_valid(avatar.movement_body):
		return avatar.movement_body.global_position
	return avatar.global_position


func _build_interaction_prompt_text_for_npc(target_name: String) -> String:
	var keybind_glyph: String = _resolve_action_keybind_glyph(String(interact_action))
	return "%s Loot %s" % [keybind_glyph, target_name]


func _build_interaction_prompt_text_for_chest(target_name: String) -> String:
	var keybind_glyph: String = _resolve_action_keybind_glyph(String(interact_action))
	return "%s Open %s" % [keybind_glyph, target_name]


func _resolve_action_keybind_glyph(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "[E]"
	var action_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event in action_events:
		var event_label: String = _resolve_input_event_label(event)
		if not event_label.is_empty():
			return "[%s]" % event_label
	return "[E]"


func _resolve_input_event_label(event: InputEvent) -> String:
	if event == null:
		return ""

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null:
		var key_label: String = key_event.as_text_key_label().strip_edges()
		if key_label.is_empty() and key_event.physical_keycode != KEY_NONE:
			key_label = OS.get_keycode_string(key_event.physical_keycode).strip_edges()
		if key_label.is_empty():
			key_label = key_event.as_text().strip_edges()
		return _sanitize_binding_label(key_label.to_upper())

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button_event != null:
		return _sanitize_binding_label(mouse_button_event.as_text().strip_edges().to_upper())

	var joypad_button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if joypad_button_event != null:
		return _sanitize_binding_label(joypad_button_event.as_text().strip_edges().to_upper())

	var joypad_motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
	if joypad_motion_event != null:
		return _sanitize_binding_label(joypad_motion_event.as_text().strip_edges().to_upper())

	return _sanitize_binding_label(event.as_text().strip_edges().to_upper())


func _sanitize_binding_label(raw_label: String) -> String:
	var label: String = raw_label.strip_edges()
	if label.begins_with("[") and label.ends_with("]") and label.length() >= 2:
		label = label.substr(1, label.length() - 2).strip_edges()
	if label.begins_with("(") and label.ends_with(")") and label.length() >= 2:
		label = label.substr(1, label.length() - 2).strip_edges()
	var lowered: String = label.to_lower()
	if lowered.is_empty():
		return ""
	if lowered == "unset":
		return ""
	if lowered == "none":
		return ""
	if lowered == "invalid":
		return ""
	if lowered == "unknown":
		return ""
	return label


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


func _find_chest_by_id(target_chest_id: int) -> StorageChest:
	if target_chest_id <= 0:
		return null
	var candidates: Array = _get_chest_candidates()
	for candidate in candidates:
		if not (candidate is StorageChest):
			continue
		var chest: StorageChest = candidate as StorageChest
		if chest != null and chest.chest_id == target_chest_id:
			return chest
	return null


func _get_chest_candidates() -> Array:
	var from_group: Array = get_tree().get_nodes_in_group("StorageChest")
	if not from_group.is_empty():
		return from_group

	# Fallback for cases where group registration lags or misses on clients.
	var all_nodes: Array = []
	var stack: Array[Node] = [get_tree().root]
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		if current is StorageChest:
			all_nodes.append(current)
		for child in current.get_children():
			if child is Node:
				stack.push_back(child)
	return all_nodes


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


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_chest_take(chest_id: int, from_slot: int, preferred_to_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_chest_take(sender_id, chest_id, from_slot, preferred_to_slot)


func _server_try_chest_take(sender_id: int, chest_id: int, from_slot: int, preferred_to_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	var chest: StorageChest = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.try_transfer_to_player(sender_id, from_slot, preferred_to_slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_chest_store(chest_id: int, from_player_slot: int, preferred_chest_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_chest_store(sender_id, chest_id, from_player_slot, preferred_chest_slot)


func _server_try_chest_store(sender_id: int, chest_id: int, from_player_slot: int, preferred_chest_slot: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	var chest: StorageChest = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.try_transfer_from_player(sender_id, from_player_slot, preferred_chest_slot)
