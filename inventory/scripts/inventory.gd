class_name Inventory
extends Node

signal inventory_changed
signal money_changed(new_money: int)
signal slot_changed(slot_index: int)

@export var max_slots: int = 8
@export var max_stack_per_slot: int = 99

var money: int = 0
var _slots: Array[Dictionary] = []
var _suppress_signals: bool = false
var _item_data_cache: Dictionary = {}


func _ready() -> void:
	_initialize_slots()


func get_money() -> int:
	return money


func get_slots() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for slot_data in _slots:
		copied.append(slot_data.duplicate(true))
	return copied


func get_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot_index(slot_index):
		return {}
	return _slots[slot_index].duplicate(true)


func is_slot_empty(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return true
	return _slots[slot_index].is_empty()


func find_first_slot_with_item(item_data_path: String) -> int:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return -1
	for slot_index in range(_slots.size()):
		var slot_data: Dictionary = _slots[slot_index]
		if slot_data.is_empty():
			continue
		if String(slot_data.get("item_data_path", "")) == normalized_item_data_path:
			return slot_index
	return -1


func find_first_empty_slot() -> int:
	for slot_index in range(_slots.size()):
		if _slots[slot_index].is_empty():
			return slot_index
	return -1


func count_item(item_data_path: String) -> int:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return 0
	var total_quantity: int = 0
	for slot_data in _slots:
		if slot_data.is_empty():
			continue
		if String(slot_data.get("item_data_path", "")) != normalized_item_data_path:
			continue
		total_quantity += int(slot_data.get("quantity", 0))
	return total_quantity


func has_item(item_data_path: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	return count_item(item_data_path) >= quantity


func can_add_item(item_data_path: String, quantity: int) -> bool:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return false
	if quantity <= 0:
		return false

	var stack_limit: int = _resolve_item_max_stack(normalized_item_data_path)
	var remaining: int = quantity
	for slot_data in _slots:
		if slot_data.is_empty():
			remaining -= stack_limit
		elif String(slot_data.get("item_data_path", "")) == normalized_item_data_path:
			var current_quantity: int = int(slot_data.get("quantity", 0))
			var free_space: int = stack_limit - current_quantity
			remaining -= maxi(free_space, 0)
		if remaining <= 0:
			return true
	return false


func try_grant_item(item_data_path: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not can_add_item(item_data_path, quantity):
		return false
	var remaining: int = add_item(item_data_path, quantity)
	return remaining == 0


func try_buy_item(item_data_path: String, price: int, quantity: int = 1) -> bool:
	if not _can_mutate():
		return false
	if price < 0:
		return false
	if quantity <= 0:
		return false
	if not can_add_item(item_data_path, quantity):
		return false
	if money < price:
		return false
	var previous_money: int = money
	var spent: bool = _set_money_internal(previous_money - price)
	if not spent and price > 0:
		return false
	var remaining: int = add_item(item_data_path, quantity)
	if remaining == 0:
		return true
	_set_money_internal(previous_money)
	return false


func try_drop_item(item_data_path: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var removed_amount: int = remove_item(item_data_path, quantity)
	return removed_amount == quantity


func set_money(value: int) -> bool:
	if not _can_mutate():
		return false
	return _set_money_internal(value)


func add_money(delta: int) -> bool:
	if not _can_mutate():
		return false
	if delta == 0:
		return false
	return _set_money_internal(money + delta)


func spend_money(cost: int) -> bool:
	if not _can_mutate():
		return false
	if cost <= 0:
		return false
	if money < cost:
		return false
	return _set_money_internal(money - cost)


func add_item(item_data_path: String, quantity: int = 1) -> int:
	if not _can_mutate():
		return quantity
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return quantity
	if quantity <= 0:
		return 0

	var stack_limit: int = _resolve_item_max_stack(normalized_item_data_path)
	var remaining: int = quantity

	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break
		var slot_data: Dictionary = _slots[slot_index]
		if slot_data.is_empty():
			continue
		if String(slot_data.get("item_data_path", "")) != normalized_item_data_path:
			continue
		var current_quantity: int = int(slot_data.get("quantity", 0))
		if current_quantity >= stack_limit:
			continue
		var add_amount: int = mini(stack_limit - current_quantity, remaining)
		slot_data["quantity"] = current_quantity + add_amount
		_slots[slot_index] = _normalize_slot(slot_data)
		remaining -= add_amount
		_emit_slot_changed(slot_index)

	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break
		if not _slots[slot_index].is_empty():
			continue
		var add_amount: int = mini(stack_limit, remaining)
		var created_slot: Dictionary = {
			"item_data_path": normalized_item_data_path,
			"quantity": add_amount
		}
		_slots[slot_index] = _normalize_slot(created_slot)
		remaining -= add_amount
		_emit_slot_changed(slot_index)

	if remaining != quantity:
		_emit_inventory_changed()
	return remaining


func remove_item(item_data_path: String, quantity: int = 1) -> int:
	if not _can_mutate():
		return 0
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return 0
	if quantity <= 0:
		return 0

	var remaining: int = quantity
	var removed_total: int = 0
	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break
		var slot_data: Dictionary = _slots[slot_index]
		if slot_data.is_empty():
			continue
		if String(slot_data.get("item_data_path", "")) != normalized_item_data_path:
			continue
		var current_quantity: int = int(slot_data.get("quantity", 0))
		var remove_amount: int = mini(current_quantity, remaining)
		var new_quantity: int = current_quantity - remove_amount
		remaining -= remove_amount
		removed_total += remove_amount
		if new_quantity <= 0:
			_slots[slot_index] = {}
		else:
			slot_data["quantity"] = new_quantity
			_slots[slot_index] = _normalize_slot(slot_data)
		_emit_slot_changed(slot_index)

	if removed_total > 0:
		_emit_inventory_changed()
	return removed_total


func set_slot(slot_index: int, item_data_path: String, quantity: int) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(slot_index):
		return false
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty() or quantity <= 0:
		_slots[slot_index] = {}
		_emit_slot_changed(slot_index)
		_emit_inventory_changed()
		return true

	var slot_data: Dictionary = {
		"item_data_path": normalized_item_data_path,
		"quantity": quantity
	}
	_slots[slot_index] = _normalize_slot(slot_data)
	_emit_slot_changed(slot_index)
	_emit_inventory_changed()
	return true


func clear_slot(slot_index: int) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(slot_index):
		return false
	if _slots[slot_index].is_empty():
		return false
	_slots[slot_index] = {}
	_emit_slot_changed(slot_index)
	_emit_inventory_changed()
	return true


func swap_slots(a: int, b: int) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(a) or not _is_valid_slot_index(b):
		return false
	if a == b:
		return false
	var temp: Dictionary = _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = temp
	_emit_slot_changed(a)
	_emit_slot_changed(b)
	_emit_inventory_changed()
	return true


func split_stack(from_slot: int, to_slot: int, quantity: int) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(from_slot) or not _is_valid_slot_index(to_slot):
		return false
	if from_slot == to_slot:
		return false
	if quantity <= 0:
		return false

	var source: Dictionary = _slots[from_slot]
	if source.is_empty():
		return false
	if _slots[to_slot].size() > 0:
		return false

	var source_quantity: int = int(source.get("quantity", 0))
	if quantity >= source_quantity:
		return false

	var source_item_data_path: String = String(source.get("item_data_path", ""))
	var source_stack_limit: int = _resolve_item_max_stack(source_item_data_path)
	var split_quantity: int = mini(quantity, source_stack_limit)
	source["quantity"] = source_quantity - split_quantity
	_slots[from_slot] = _normalize_slot(source)
	_slots[to_slot] = _normalize_slot({
		"item_data_path": source_item_data_path,
		"quantity": split_quantity
	})
	_emit_slot_changed(from_slot)
	_emit_slot_changed(to_slot)
	_emit_inventory_changed()
	return true


func merge_stack(from_slot: int, to_slot: int) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(from_slot) or not _is_valid_slot_index(to_slot):
		return false
	if from_slot == to_slot:
		return false

	var source: Dictionary = _slots[from_slot]
	var target: Dictionary = _slots[to_slot]
	if source.is_empty() or target.is_empty():
		return false
	if String(source.get("item_data_path", "")) != String(target.get("item_data_path", "")):
		return false

	var target_item_data_path: String = String(target.get("item_data_path", ""))
	var stack_limit: int = _resolve_item_max_stack(target_item_data_path)
	var source_quantity: int = int(source.get("quantity", 0))
	var target_quantity: int = int(target.get("quantity", 0))
	var free_space: int = stack_limit - target_quantity
	if free_space <= 0:
		return false
	var move_quantity: int = mini(source_quantity, free_space)
	if move_quantity <= 0:
		return false

	source_quantity -= move_quantity
	target_quantity += move_quantity
	target["quantity"] = target_quantity
	_slots[to_slot] = _normalize_slot(target)

	if source_quantity <= 0:
		_slots[from_slot] = {}
	else:
		source["quantity"] = source_quantity
		_slots[from_slot] = _normalize_slot(source)

	_emit_slot_changed(from_slot)
	_emit_slot_changed(to_slot)
	_emit_inventory_changed()
	return true


func serialize_slots_json() -> String:
	var payload: Array = []
	for slot_data in _slots:
		payload.append(slot_data.duplicate(true))
	return JSON.stringify(payload)


func deserialize_slots_json(serialized: String) -> bool:
	var parsed: Variant = JSON.parse_string(serialized)
	if typeof(parsed) != TYPE_ARRAY:
		return false
	var parsed_array: Array = parsed as Array
	var normalized: Array[Dictionary] = _empty_slot_array()
	for slot_index in range(mini(parsed_array.size(), normalized.size())):
		var raw_slot: Variant = parsed_array[slot_index]
		if typeof(raw_slot) != TYPE_DICTIONARY:
			continue
		var raw_dictionary: Dictionary = raw_slot as Dictionary
		normalized[slot_index] = _normalize_slot(raw_dictionary)
	_set_slots_internal(normalized)
	return true


func apply_snapshot_from_network(slots_json: String, new_money: int) -> void:
	_suppress_signals = true
	_set_money_internal(new_money)
	deserialize_slots_json(slots_json)
	_suppress_signals = false
	_emit_inventory_changed()


func _initialize_slots() -> void:
	_slots = _empty_slot_array()


func _empty_slot_array() -> Array[Dictionary]:
	var sized: Array[Dictionary] = []
	var slot_count: int = maxi(max_slots, 1)
	for _i in range(slot_count):
		sized.append({})
	return sized


func _normalize_slot(slot_data: Dictionary) -> Dictionary:
	var item_data_path: String = String(slot_data.get("item_data_path", "")).strip_edges()
	if item_data_path.is_empty():
		return {}
	var quantity: int = int(slot_data.get("quantity", 0))
	var stack_limit: int = _resolve_item_max_stack(item_data_path)
	quantity = clampi(quantity, 1, stack_limit)
	return {
		"item_data_path": item_data_path,
		"quantity": quantity
	}


func _resolve_item_max_stack(item_data_path: String) -> int:
	var resolved_max: int = maxi(max_stack_per_slot, 1)
	var item_data: Resource = _resolve_item_data(item_data_path)
	if item_data == null:
		return resolved_max
	var max_stack_variant: Variant = item_data.get("max_stack")
	if typeof(max_stack_variant) == TYPE_INT:
		resolved_max = mini(resolved_max, maxi(int(max_stack_variant), 1))
	return maxi(resolved_max, 1)


func _resolve_item_data(item_data_path: String) -> Resource:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return null
	if _item_data_cache.has(normalized_item_data_path):
		var cached_variant: Variant = _item_data_cache.get(normalized_item_data_path)
		if cached_variant is Resource:
			return cached_variant as Resource
		return null

	var loaded_resource: Resource = load(normalized_item_data_path)
	if loaded_resource != null:
		_item_data_cache[normalized_item_data_path] = loaded_resource
		return loaded_resource
	_item_data_cache[normalized_item_data_path] = null
	return null


func _set_slots_internal(new_slots: Array[Dictionary]) -> void:
	_slots = _empty_slot_array()
	for slot_index in range(mini(new_slots.size(), _slots.size())):
		_slots[slot_index] = _normalize_slot(new_slots[slot_index])
	_emit_inventory_changed()


func _set_money_internal(value: int) -> bool:
	var clamped_money: int = maxi(value, 0)
	if money == clamped_money:
		return false
	money = clamped_money
	if not _suppress_signals:
		money_changed.emit(money)
	return true


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size()


func _can_mutate() -> bool:
	return true


func _emit_slot_changed(slot_index: int) -> void:
	if _suppress_signals:
		return
	slot_changed.emit(slot_index)


func _emit_inventory_changed() -> void:
	if _suppress_signals:
		return
	inventory_changed.emit()
