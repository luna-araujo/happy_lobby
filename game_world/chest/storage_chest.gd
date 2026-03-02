class_name StorageChest
extends StaticBody3D

const BERETTA_ITEM_DATA_PATH: String = "res://items/beretta/beretta_item_data.tres"

@export var chest_id: int = 0
@export var display_name: String = "Chest"
@export var interaction_range: float = 2.5
@export var transfer_range_extra: float = 0.4
@export var seed_item_data_paths: PackedStringArray = PackedStringArray([BERETTA_ITEM_DATA_PATH, BERETTA_ITEM_DATA_PATH, BERETTA_ITEM_DATA_PATH])
@export var seed_money: int = 0

var inventory: Inventory
var _applying_network_inventory_state: bool = false

var _network_inventory_slots_json: String = "[]"
var network_inventory_slots_json: String:
	get:
		return _network_inventory_slots_json
	set(value):
		if _network_inventory_slots_json == value:
			return
		_network_inventory_slots_json = value
		if is_multiplayer_authority():
			return
		_apply_network_inventory_state()

var _network_inventory_money: int = 0
var network_inventory_money: int:
	get:
		return _network_inventory_money
	set(value):
		var clamped_value: int = maxi(value, 0)
		if _network_inventory_money == clamped_value:
			return
		_network_inventory_money = clamped_value
		if is_multiplayer_authority():
			return
		_apply_network_inventory_state()


func _ready() -> void:
	if chest_id <= 0:
		# Ensure a valid network identifier even if scene value is missing/overridden.
		chest_id = int(abs(String(get_path()).hash())) + 1

	add_to_group("StorageChest")
	inventory = get_node_or_null("Inventory") as Inventory

	if inventory != null:
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)
		if not inventory.money_changed.is_connected(_on_inventory_money_changed):
			inventory.money_changed.connect(_on_inventory_money_changed)

	if is_multiplayer_authority():
		_seed_inventory_if_authority()
		_sync_network_inventory_from_authority()
	else:
		_apply_network_inventory_state()

	if display_name.strip_edges().is_empty():
		display_name = "Chest_%d" % chest_id


func can_be_accessed_by(player_peer_id: int, max_distance: float) -> bool:
	if player_peer_id <= 0:
		return false
	var avatar: Avatar = _find_avatar_by_player_id(player_peer_id)
	if avatar == null:
		return false
	var allowed_range: float = maxf(max_distance, 0.1)
	var avatar_position: Vector3 = _get_avatar_interaction_position(avatar)
	return avatar_position.distance_to(global_position) <= allowed_range


func try_transfer_to_player(player_peer_id: int, from_slot: int, _preferred_player_slot: int = -1) -> bool:
	if not multiplayer.is_server():
		return false
	if not can_be_accessed_by(player_peer_id, interaction_range + maxf(transfer_range_extra, 0.0)):
		return false
	if inventory == null:
		return false

	var source_slot: Dictionary = inventory.get_slot(from_slot)
	if source_slot.is_empty():
		return false
	var item_data_path: String = String(source_slot.get("item_data_path", "")).strip_edges()
	if item_data_path.is_empty():
		return false
	var source_quantity: int = int(source_slot.get("quantity", 0))
	if source_quantity <= 0:
		return false

	var avatar: Avatar = _find_avatar_by_player_id(player_peer_id)
	if avatar == null:
		return false
	if avatar.inventory == null:
		return false

	var remaining: int = avatar.inventory.add_item(item_data_path, source_quantity)
	var moved_amount: int = source_quantity - remaining
	if moved_amount <= 0:
		return false

	var new_quantity: int = source_quantity - moved_amount
	if new_quantity <= 0:
		inventory.clear_slot(from_slot)
	else:
		inventory.set_slot(from_slot, item_data_path, new_quantity)
	return true


func try_transfer_from_player(player_peer_id: int, from_player_slot: int, _preferred_chest_slot: int = -1) -> bool:
	if not multiplayer.is_server():
		return false
	if not can_be_accessed_by(player_peer_id, interaction_range + maxf(transfer_range_extra, 0.0)):
		return false
	if inventory == null:
		return false

	var avatar: Avatar = _find_avatar_by_player_id(player_peer_id)
	if avatar == null:
		return false
	if avatar.inventory == null:
		return false

	var player_slot: Dictionary = avatar.inventory.get_slot(from_player_slot)
	if player_slot.is_empty():
		return false
	var item_data_path: String = String(player_slot.get("item_data_path", "")).strip_edges()
	if item_data_path.is_empty():
		return false
	var source_quantity: int = int(player_slot.get("quantity", 0))
	if source_quantity <= 0:
		return false

	var remaining: int = inventory.add_item(item_data_path, source_quantity)
	var moved_amount: int = source_quantity - remaining
	if moved_amount <= 0:
		return false

	var new_quantity: int = source_quantity - moved_amount
	if new_quantity <= 0:
		avatar.inventory.clear_slot(from_player_slot)
	else:
		avatar.inventory.set_slot(from_player_slot, item_data_path, new_quantity)
	return true


func _seed_inventory_if_authority() -> void:
	if inventory == null:
		return
	for item_data_path in seed_item_data_paths:
		var normalized_item_data_path: String = String(item_data_path).strip_edges()
		if normalized_item_data_path.is_empty():
			continue
		inventory.try_grant_item(normalized_item_data_path, 1)
	if seed_money > 0:
		inventory.set_money(seed_money)


func _on_inventory_changed() -> void:
	if inventory == null:
		return
	if _applying_network_inventory_state:
		return
	if not is_multiplayer_authority():
		return
	_sync_network_inventory_from_authority()


func _on_inventory_money_changed(_new_money: int) -> void:
	_on_inventory_changed()


func _sync_network_inventory_from_authority() -> void:
	if inventory == null:
		return
	network_inventory_slots_json = inventory.serialize_slots_json()
	network_inventory_money = inventory.get_money()


func _apply_network_inventory_state() -> void:
	if inventory == null:
		return
	if is_multiplayer_authority():
		return
	_applying_network_inventory_state = true
	inventory.apply_snapshot_from_network(_network_inventory_slots_json, _network_inventory_money)
	_applying_network_inventory_state = false


func _find_avatar_by_player_id(target_player_id: int) -> Avatar:
	var world_root: Node = get_tree().root
	var stack: Array[Node] = []
	stack.push_back(world_root)
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		if current is Avatar:
			var avatar_node: Avatar = current as Avatar
			if avatar_node.player_id == target_player_id:
				return avatar_node
		var children: Array = current.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child)
	return null


func _get_avatar_interaction_position(avatar: Avatar) -> Vector3:
	if avatar == null:
		return Vector3.ZERO
	if avatar.movement_body != null and is_instance_valid(avatar.movement_body):
		return avatar.movement_body.global_position
	return avatar.global_position
