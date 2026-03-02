extends Node

@export var interact_action: StringName = &"interact"
@export var max_interaction_distance: float = 2.5
@export var crosshair_dot_threshold: float = 0.35
@export var refresh_interval_seconds: float = 0.05
@export var show_binding_in_prompt: bool = true

const EXECUTION_MODE_LOCAL_ONLY: int = 0
const EXECUTION_MODE_SERVER_ONLY: int = 1
const EXECUTION_MODE_LOCAL_AND_SERVER: int = 2

var avatar: Avatar
var _active_area: Node
var _refresh_cooldown: float = 0.0
var _was_local_controlled: bool = false


func _ready() -> void:
	avatar = get_parent() as Avatar


func _process(delta: float) -> void:
	if avatar == null:
		return
	var is_local_controlled: bool = avatar._is_local_controlled()
	if not is_local_controlled:
		# Remote avatar interactor instances must never drive local HUD prompt state.
		if _was_local_controlled:
			_set_interaction_prompt_visible(false)
			_active_area = null
			_refresh_cooldown = 0.0
		_was_local_controlled = false
		return

	_was_local_controlled = true

	_refresh_cooldown = maxf(_refresh_cooldown - maxf(delta, 0.0), 0.0)
	if _refresh_cooldown <= 0.0:
		_refresh_cooldown = maxf(refresh_interval_seconds, 0.01)
		_update_active_area()

	if Input.is_action_just_pressed(String(interact_action)):
		_interact_with_active_area()


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


func request_chest_drop_to_world(chest_id: int, from_slot: int, quantity: int = 1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if chest_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return

	if multiplayer.is_server():
		_server_try_chest_drop_to_world(avatar.player_id, chest_id, from_slot, quantity)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_chest_drop_to_world.rpc_id(host_id, chest_id, from_slot, quantity)


func request_npc_drop_to_world(npc_id: int, from_slot: int, quantity: int = 1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if npc_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return

	if multiplayer.is_server():
		_server_try_npc_drop_to_world(avatar.player_id, npc_id, from_slot, quantity)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_npc_drop_to_world.rpc_id(host_id, npc_id, from_slot, quantity)


func request_chest_split_stack(chest_id: int, from_slot: int, quantity: int = 1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if chest_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return

	if multiplayer.is_server():
		_server_try_chest_split_stack(avatar.player_id, chest_id, from_slot, quantity)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_chest_split_stack.rpc_id(host_id, chest_id, from_slot, quantity)


func request_npc_split_stack(npc_id: int, from_slot: int, quantity: int = 1) -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if npc_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return

	if multiplayer.is_server():
		_server_try_npc_split_stack(avatar.player_id, npc_id, from_slot, quantity)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_npc_split_stack.rpc_id(host_id, npc_id, from_slot, quantity)


func _update_active_area() -> void:
	_active_area = _find_best_interaction_area()
	if _active_area == null:
		_set_interaction_prompt_visible(false)
		return
	var resolved_prompt: String = _area_get_prompt_text(_active_area).strip_edges()
	if resolved_prompt.is_empty():
		_set_interaction_prompt_visible(false)
		return
	_set_interaction_prompt_text(_build_prompt_text(resolved_prompt))


func _find_best_interaction_area() -> Node:
	var camera_position: Vector3 = _resolve_camera_position()
	var camera_forward: Vector3 = _resolve_camera_forward()
	if camera_forward.length_squared() <= 0.0001:
		camera_forward = Vector3.FORWARD
	camera_forward = camera_forward.normalized()

	var required_dot: float = clampf(crosshair_dot_threshold, -1.0, 1.0)
	var best_area: Node = null
	var best_dot: float = -2.0
	var best_distance_sq: float = INF
	var best_priority: int = -2147483648

	var candidates: Array = get_tree().get_nodes_in_group("InteractionArea")
	for candidate in candidates:
		if not (candidate is Node):
			continue
		var area: Node = candidate as Node
		if area == null:
			continue
		if not is_instance_valid(area):
			continue
		if not _area_can_interact(area):
			continue

		var target_position: Vector3 = _area_get_target_position(area)
		var to_target: Vector3 = target_position - camera_position
		var distance_sq: float = to_target.length_squared()
		if distance_sq <= 0.0001:
			continue
		var distance: float = sqrt(distance_sq)
		var target_direction: Vector3 = to_target / maxf(distance, 0.0001)
		var aim_dot: float = camera_forward.dot(target_direction)
		if aim_dot < required_dot:
			continue

		var should_replace: bool = false
		if best_area == null:
			should_replace = true
		elif aim_dot > best_dot + 0.0001:
			should_replace = true
		elif is_equal_approx(aim_dot, best_dot):
			if distance_sq < best_distance_sq - 0.0001:
				should_replace = true
			elif is_equal_approx(distance_sq, best_distance_sq) and _area_get_priority(area) > best_priority:
				should_replace = true

		if not should_replace:
			continue
		best_area = area
		best_dot = aim_dot
		best_distance_sq = distance_sq
		best_priority = _area_get_priority(area)

	return best_area


func _interact_with_active_area() -> void:
	if _active_area == null:
		return
	if not is_instance_valid(_active_area):
		_active_area = null
		_set_interaction_prompt_visible(false)
		return
	if not _area_can_interact(_active_area):
		return

	var resolved_action_id: StringName = _area_get_action_id(_active_area)
	match _area_get_execution_mode(_active_area):
		EXECUTION_MODE_LOCAL_ONLY:
			_area_interact_local(_active_area, resolved_action_id)
		EXECUTION_MODE_SERVER_ONLY:
			_dispatch_server_interaction(_active_area, resolved_action_id)
		EXECUTION_MODE_LOCAL_AND_SERVER:
			_area_interact_local(_active_area, resolved_action_id)
			_dispatch_server_interaction(_active_area, resolved_action_id)


func _dispatch_server_interaction(area: Node, resolved_action_id: StringName) -> void:
	if area == null:
		return
	if avatar == null:
		return
	if multiplayer.is_server():
		if _area_can_interact_server(area, avatar, avatar.player_id):
			_area_interact_server(area, avatar.player_id, resolved_action_id)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_interaction.rpc_id(host_id, area.get_path(), resolved_action_id)


func _build_prompt_text(base_prompt: String) -> String:
	if not show_binding_in_prompt:
		return base_prompt
	var keybind_glyph: String = _resolve_action_keybind_glyph(String(interact_action))
	return "%s %s" % [keybind_glyph, base_prompt]


func _area_can_interact(area: Node) -> bool:
	if area == null:
		return false
	if not area.has_method("can_interact"):
		return false
	var result: Variant = area.call("can_interact", self)
	if typeof(result) != TYPE_BOOL:
		return false
	return bool(result)


func _area_can_interact_server(area: Node, source_avatar: Avatar, source_peer_id: int) -> bool:
	if area == null:
		return false
	if not area.has_method("can_interact_server"):
		return false
	var result: Variant = area.call("can_interact_server", source_avatar, source_peer_id)
	if typeof(result) != TYPE_BOOL:
		return false
	return bool(result)


func _area_get_target_position(area: Node) -> Vector3:
	if area == null:
		return Vector3.ZERO
	if not area.has_method("get_target_position"):
		var area_3d: Node3D = area as Node3D
		if area_3d != null:
			return area_3d.global_position
		return Vector3.ZERO
	var result: Variant = area.call("get_target_position", self)
	if typeof(result) != TYPE_VECTOR3:
		return Vector3.ZERO
	return result as Vector3


func _area_get_priority(area: Node) -> int:
	if area == null:
		return 0
	var priority_value: Variant = area.get("interaction_priority")
	if typeof(priority_value) != TYPE_INT:
		priority_value = area.get("priority")
	if typeof(priority_value) != TYPE_INT:
		return 0
	return int(priority_value)


func _area_get_action_id(area: Node) -> StringName:
	if area == null:
		return &"interact"
	if not area.has_method("get_action_id"):
		return &"interact"
	var result: Variant = area.call("get_action_id", self)
	if typeof(result) != TYPE_STRING_NAME and typeof(result) != TYPE_STRING:
		return &"interact"
	return StringName(String(result))


func _area_get_prompt_text(area: Node) -> String:
	if area == null:
		return ""
	if not area.has_method("get_prompt_text"):
		return ""
	var result: Variant = area.call("get_prompt_text", self)
	if typeof(result) != TYPE_STRING and typeof(result) != TYPE_STRING_NAME:
		return ""
	return String(result).strip_edges()


func _area_get_execution_mode(area: Node) -> int:
	if area == null:
		return EXECUTION_MODE_LOCAL_ONLY
	var mode_value: Variant = area.get("execution_mode")
	if typeof(mode_value) != TYPE_INT:
		return EXECUTION_MODE_LOCAL_ONLY
	return int(mode_value)


func _area_interact_local(area: Node, resolved_action_id: StringName) -> void:
	if area == null:
		return
	if not area.has_method("interact_local"):
		return
	area.call("interact_local", self, resolved_action_id)


func _area_interact_server(area: Node, source_peer_id: int, resolved_action_id: StringName) -> void:
	if area == null:
		return
	if not area.has_method("interact_server"):
		return
	area.call("interact_server", source_peer_id, resolved_action_id)


func _set_interaction_prompt_text(text: String) -> void:
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	UIManager.player_ui.set_interaction_prompt(text)


func _set_interaction_prompt_visible(is_visible: bool) -> void:
	if UIManager == null:
		return
	if UIManager.player_ui == null:
		return
	UIManager.player_ui.set_interaction_prompt_visible(is_visible)


func _resolve_camera_position() -> Vector3:
	var camera: Camera3D = _resolve_active_camera()
	if camera != null:
		return camera.global_position
	return _get_avatar_interaction_position()


func _resolve_camera_forward() -> Vector3:
	var camera: Camera3D = _resolve_active_camera()
	if camera != null:
		var basis_forward: Vector3 = -camera.global_basis.z
		if basis_forward.length_squared() > 0.0001:
			return basis_forward.normalized()
	var avatar_forward: Vector3 = -avatar.global_basis.z
	if avatar_forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return avatar_forward.normalized()


func _resolve_active_camera() -> Camera3D:
	if avatar == null:
		return null
	if avatar.third_person_camera == null:
		return null
	if not is_instance_valid(avatar.third_person_camera):
		return null
	if avatar.third_person_camera.camera_3d == null:
		return null
	if not is_instance_valid(avatar.third_person_camera.camera_3d):
		return null
	return avatar.third_person_camera.camera_3d


func _get_avatar_interaction_position() -> Vector3:
	if avatar == null:
		return Vector3.ZERO
	if avatar.movement_body != null and is_instance_valid(avatar.movement_body):
		return avatar.movement_body.global_position
	return avatar.global_position


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


func _find_chest_by_id(target_chest_id: int) -> Node3D:
	if target_chest_id <= 0:
		return null
	var candidates: Array = _get_chest_candidates()
	for candidate in candidates:
		if not (candidate is Node3D):
			continue
		var chest: Node3D = candidate as Node3D
		if chest == null:
			continue
		if not _node_looks_like_chest(chest):
			continue
		var candidate_id: int = int(chest.get("chest_id"))
		if candidate_id == target_chest_id:
			return chest
	return null


func _get_chest_candidates() -> Array:
	var merged: Array = []
	var seen: Dictionary = {}
	var from_group: Array = get_tree().get_nodes_in_group("StorageChest")
	for candidate in from_group:
		if not (candidate is Node):
			continue
		var node_candidate: Node = candidate as Node
		if node_candidate == null:
			continue
		var key: int = node_candidate.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(node_candidate)

	var all_nodes: Array = []
	var stack: Array[Node] = [get_tree().root]
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		if _node_looks_like_chest(current):
			var key: int = current.get_instance_id()
			if not seen.has(key):
				seen[key] = true
				all_nodes.append(current)
		for child in current.get_children():
			if child is Node:
				stack.push_back(child)
	merged.append_array(all_nodes)
	return merged


func _node_looks_like_chest(node: Node) -> bool:
	if node == null:
		return false
	if not (node is Node3D):
		return false
	if node.is_in_group("StorageChest"):
		return true
	if not node.has_node("Inventory"):
		return false
	var chest_id_variant: Variant = node.get("chest_id")
	if typeof(chest_id_variant) == TYPE_INT:
		return int(chest_id_variant) > 0
	return false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_interaction(target_path: NodePath, action_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	if target_path.is_empty():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return

	var target_node: Node = get_node_or_null(target_path)
	if target_node == null:
		target_node = get_tree().root.get_node_or_null(target_path)
	if target_node == null:
		return
	if not target_node.is_in_group("InteractionArea"):
		return
	if not _area_can_interact_server(target_node, avatar, sender_id):
		return
	_area_interact_server(target_node, sender_id, action_id)


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
	var chest: Node3D = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.call("try_transfer_to_player", sender_id, from_slot, preferred_to_slot)


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
	var chest: Node3D = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.call("try_transfer_from_player", sender_id, from_player_slot, preferred_chest_slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_chest_drop_to_world(chest_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_chest_drop_to_world(sender_id, chest_id, from_slot, quantity)


func _server_try_chest_drop_to_world(sender_id: int, chest_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return
	var chest: Node3D = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.call("try_drop_slot_to_world", sender_id, from_slot, quantity)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_npc_drop_to_world(npc_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_npc_drop_to_world(sender_id, npc_id, from_slot, quantity)


func _server_try_npc_drop_to_world(sender_id: int, npc_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return
	var npc: TestNpc = _find_npc_by_id(npc_id)
	if npc == null:
		return
	npc.call("try_drop_loot_slot_to_world", sender_id, from_slot, quantity)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_chest_split_stack(chest_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_chest_split_stack(sender_id, chest_id, from_slot, quantity)


func _server_try_chest_split_stack(sender_id: int, chest_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return
	var chest: Node3D = _find_chest_by_id(chest_id)
	if chest == null:
		return
	chest.call("try_split_slot", sender_id, from_slot, quantity)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_npc_split_stack(npc_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_try_npc_split_stack(sender_id, npc_id, from_slot, quantity)


func _server_try_npc_split_stack(sender_id: int, npc_id: int, from_slot: int, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	if sender_id <= 0:
		return
	if from_slot < 0:
		return
	if quantity <= 0:
		return
	var npc: TestNpc = _find_npc_by_id(npc_id)
	if npc == null:
		return
	npc.call("try_split_loot_slot", sender_id, from_slot, quantity)
