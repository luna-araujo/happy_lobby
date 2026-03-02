class_name StorageChest
extends StaticBody3D

const BERETTA_ITEM_DATA_PATH: String = "res://items/beretta/beretta_item_data.tres"
const HEALTH_POTION_ITEM_DATA_PATH: String = "res://items/consumables/health_potion_item_data.tres"

@export var chest_id: int = 0
@export var display_name: String = "Chest"
@export var interaction_range: float = 2.5
@export var transfer_range_extra: float = 0.4
@export var seed_item_data_paths: PackedStringArray = PackedStringArray([
	BERETTA_ITEM_DATA_PATH,
	HEALTH_POTION_ITEM_DATA_PATH,
	HEALTH_POTION_ITEM_DATA_PATH
])
@export var seed_item_quantities: Dictionary = {}
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


func try_transfer_to_player(player_peer_id: int, from_slot: int, preferred_player_slot: int = -1) -> bool:
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

	var remaining: int = _add_item_with_preferred_slot(avatar.inventory, item_data_path, source_quantity, preferred_player_slot)
	var moved_amount: int = source_quantity - remaining
	if moved_amount <= 0:
		return false

	var new_quantity: int = source_quantity - moved_amount
	if new_quantity <= 0:
		inventory.clear_slot(from_slot)
	else:
		inventory.set_slot(from_slot, item_data_path, new_quantity)
	return true


func try_transfer_from_player(player_peer_id: int, from_player_slot: int, preferred_chest_slot: int = -1) -> bool:
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

	var remaining: int = _add_item_with_preferred_slot(inventory, item_data_path, source_quantity, preferred_chest_slot)
	var moved_amount: int = source_quantity - remaining
	if moved_amount <= 0:
		return false

	var new_quantity: int = source_quantity - moved_amount
	if new_quantity <= 0:
		avatar.inventory.clear_slot(from_player_slot)
	else:
		avatar.inventory.set_slot(from_player_slot, item_data_path, new_quantity)
	return true


func try_drop_slot_to_world(player_peer_id: int, from_slot: int, quantity: int = 1) -> bool:
	if not multiplayer.is_server():
		return false
	if quantity <= 0:
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

	var world: NeoWorld = _find_world_root()
	if world == null:
		return false

	var drop_quantity: int = mini(quantity, source_quantity)
	if drop_quantity <= 0:
		return false
	var drop_start_position: Vector3 = global_position + Vector3.UP * 0.95
	var drop_target_anchor: Vector3 = global_position
	var remaining_quantity: int = source_quantity - drop_quantity
	if remaining_quantity <= 0:
		inventory.clear_slot(from_slot)
	else:
		inventory.set_slot(from_slot, item_data_path, remaining_quantity)

	var spawned_item: DroppedItem = world.spawn_dropped_item(
		item_data_path,
		drop_quantity,
		drop_start_position,
		drop_target_anchor
	)
	if spawned_item == null:
		inventory.set_slot(from_slot, item_data_path, source_quantity)
		return false
	return true


func try_split_slot(player_peer_id: int, from_slot: int, quantity: int = 1) -> bool:
	if not multiplayer.is_server():
		return false
	if quantity <= 0:
		return false
	if not can_be_accessed_by(player_peer_id, interaction_range + maxf(transfer_range_extra, 0.0)):
		return false
	if inventory == null:
		return false

	var source_slot: Dictionary = inventory.get_slot(from_slot)
	if source_slot.is_empty():
		return false
	var source_quantity: int = int(source_slot.get("quantity", 0))
	if source_quantity <= 1:
		return false
	var split_quantity: int = clampi(quantity, 1, source_quantity - 1)
	if split_quantity <= 0:
		return false

	var to_slot: int = inventory.find_first_empty_slot()
	if to_slot >= 0 and inventory.split_stack(from_slot, to_slot, split_quantity):
		return true
	return try_drop_slot_to_world(player_peer_id, from_slot, split_quantity)


func _seed_inventory_if_authority() -> void:
	if inventory == null:
		return
	for item_data_key in seed_item_quantities.keys():
		var normalized_item_data_path: String = String(item_data_key).strip_edges()
		if normalized_item_data_path.is_empty():
			continue
		var quantity_variant: Variant = seed_item_quantities.get(item_data_key, 0)
		var quantity: int = 0
		if typeof(quantity_variant) == TYPE_INT:
			quantity = int(quantity_variant)
		elif typeof(quantity_variant) == TYPE_FLOAT:
			quantity = int(quantity_variant)
		quantity = maxi(quantity, 0)
		if quantity <= 0:
			continue
		inventory.try_grant_item(normalized_item_data_path, quantity)
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


func _find_world_root() -> NeoWorld:
	var current: Node = self
	while current != null:
		if current is NeoWorld:
			return current as NeoWorld
		current = current.get_parent()
	return null


func _add_item_with_preferred_slot(target_inventory: Inventory, item_data_path: String, quantity: int, preferred_slot: int) -> int:
	if target_inventory == null:
		return quantity
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return quantity
	if quantity <= 0:
		return 0

	var remaining: int = quantity
	if preferred_slot >= 0:
		remaining = _try_add_item_to_specific_slot(target_inventory, normalized_item_data_path, remaining, preferred_slot)
		if remaining <= 0:
			return 0

	return target_inventory.add_item(normalized_item_data_path, remaining)


func _try_add_item_to_specific_slot(target_inventory: Inventory, item_data_path: String, quantity: int, target_slot: int) -> int:
	var slot_data: Dictionary = target_inventory.get_slot(target_slot)
	var stack_limit: int = _resolve_target_stack_limit(target_inventory, item_data_path)
	if stack_limit <= 0:
		return quantity

	if slot_data.is_empty():
		var add_amount: int = mini(quantity, stack_limit)
		if add_amount > 0:
			target_inventory.set_slot(target_slot, item_data_path, add_amount)
		return quantity - add_amount

	var current_item_data_path: String = String(slot_data.get("item_data_path", "")).strip_edges()
	if current_item_data_path != item_data_path:
		return quantity

	var current_quantity: int = int(slot_data.get("quantity", 0))
	var free_space: int = maxi(stack_limit - current_quantity, 0)
	if free_space <= 0:
		return quantity

	var add_amount: int = mini(quantity, free_space)
	target_inventory.set_slot(target_slot, item_data_path, current_quantity + add_amount)
	return quantity - add_amount


func _resolve_target_stack_limit(target_inventory: Inventory, item_data_path: String) -> int:
	var resolved_limit: int = maxi(target_inventory.max_stack_per_slot, 1)
	var item_data: Resource = load(item_data_path)
	if item_data != null:
		var max_stack_variant: Variant = item_data.get("max_stack")
		if typeof(max_stack_variant) == TYPE_INT:
			resolved_limit = mini(resolved_limit, maxi(int(max_stack_variant), 1))
	return maxi(resolved_limit, 1)
