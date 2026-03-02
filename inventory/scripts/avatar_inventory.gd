class_name AvatarInventory
extends Inventory

signal gun_slot_changed

var _gun_slot: Dictionary = {}


func _initialize_slots() -> void:
	super._initialize_slots()
	_gun_slot = {}


func get_gun_slot() -> Dictionary:
	return _gun_slot.duplicate(true)


func is_gun_slot_empty() -> bool:
	return _gun_slot.is_empty()


func can_set_gun_slot(item_data_path: String) -> bool:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return false
	return _is_gun_item_path(normalized_item_data_path)


func count_item(item_data_path: String) -> int:
	var total_quantity: int = super.count_item(item_data_path)
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return total_quantity
	if String(_gun_slot.get("item_data_path", "")) == normalized_item_data_path:
		total_quantity += int(_gun_slot.get("quantity", 0))
	return total_quantity


func remove_item(item_data_path: String, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	var removed_total: int = super.remove_item(item_data_path, quantity)
	var removed_from_slots: int = removed_total
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return removed_total

	var remaining: int = quantity - removed_total
	if remaining <= 0:
		return removed_total
	if _gun_slot.is_empty():
		return removed_total
	if String(_gun_slot.get("item_data_path", "")) != normalized_item_data_path:
		return removed_total

	var gun_quantity: int = int(_gun_slot.get("quantity", 0))
	var remove_from_gun: int = mini(gun_quantity, remaining)
	if remove_from_gun <= 0:
		return removed_total
	gun_quantity -= remove_from_gun
	removed_total += remove_from_gun
	if gun_quantity <= 0:
		_gun_slot = {}
	else:
		_gun_slot["quantity"] = gun_quantity
		_gun_slot = _normalize_gun_slot(_gun_slot)
	_emit_gun_slot_changed()
	if removed_from_slots == 0:
		_emit_inventory_changed()
	return removed_total


func equip_gun_from_slot(from_slot: int, preferred_return_slot: int = -1) -> bool:
	if not _can_mutate():
		return false
	if not _is_valid_slot_index(from_slot):
		return false
	var source_slot: Dictionary = _slots[from_slot]
	if source_slot.is_empty():
		return false

	var source_item_data_path: String = String(source_slot.get("item_data_path", "")).strip_edges()
	if not can_set_gun_slot(source_item_data_path):
		return false

	var old_gun_slot: Dictionary = _gun_slot.duplicate(true)
	if not old_gun_slot.is_empty():
		var target_index: int = -1
		if _is_valid_slot_index(preferred_return_slot) and _slots[preferred_return_slot].is_empty():
			target_index = preferred_return_slot
		elif _slots[from_slot].is_empty():
			target_index = from_slot
		else:
			target_index = find_first_empty_slot()
		if target_index < 0:
			return false
		_slots[target_index] = _normalize_slot(old_gun_slot)
		_emit_slot_changed(target_index)

	_slots[from_slot] = {}
	_emit_slot_changed(from_slot)
	_gun_slot = _normalize_gun_slot(source_slot)
	_emit_gun_slot_changed()
	_emit_inventory_changed()
	return true


func unequip_gun_to_inventory(preferred_slot: int = -1) -> bool:
	if not _can_mutate():
		return false
	if _gun_slot.is_empty():
		return false

	var target_slot: int = -1
	if _is_valid_slot_index(preferred_slot) and _slots[preferred_slot].is_empty():
		target_slot = preferred_slot
	else:
		target_slot = find_first_empty_slot()
	if target_slot < 0:
		return false

	_slots[target_slot] = _normalize_slot(_gun_slot)
	_gun_slot = {}
	_emit_slot_changed(target_slot)
	_emit_gun_slot_changed()
	_emit_inventory_changed()
	return true


func serialize_slots_json() -> String:
	var payload_slots: Array = []
	for slot_data in _slots:
		payload_slots.append(slot_data.duplicate(true))
	var payload: Dictionary = {
		"slots": payload_slots,
		"gun_slot": _gun_slot.duplicate(true)
	}
	return JSON.stringify(payload)


func deserialize_slots_json(serialized: String) -> bool:
	var parsed: Variant = JSON.parse_string(serialized)
	var normalized_slots: Array[Dictionary] = _empty_slot_array()
	var normalized_gun_slot: Dictionary = {}

	if typeof(parsed) == TYPE_ARRAY:
		var parsed_array: Array = parsed as Array
		for slot_index in range(mini(parsed_array.size(), normalized_slots.size())):
			var raw_slot: Variant = parsed_array[slot_index]
			if typeof(raw_slot) != TYPE_DICTIONARY:
				continue
			normalized_slots[slot_index] = _normalize_slot(raw_slot as Dictionary)
	elif typeof(parsed) == TYPE_DICTIONARY:
		var parsed_dictionary: Dictionary = parsed as Dictionary
		var slots_variant: Variant = parsed_dictionary.get("slots", [])
		if typeof(slots_variant) == TYPE_ARRAY:
			var slots_array: Array = slots_variant as Array
			for slot_index in range(mini(slots_array.size(), normalized_slots.size())):
				var raw_slot: Variant = slots_array[slot_index]
				if typeof(raw_slot) != TYPE_DICTIONARY:
					continue
				normalized_slots[slot_index] = _normalize_slot(raw_slot as Dictionary)
		var gun_slot_variant: Variant = parsed_dictionary.get("gun_slot", {})
		if typeof(gun_slot_variant) == TYPE_DICTIONARY:
			normalized_gun_slot = _normalize_gun_slot(gun_slot_variant as Dictionary)
	else:
		return false

	_set_inventory_state_internal(normalized_slots)
	var previous_gun_slot: Dictionary = _gun_slot.duplicate(true)
	_gun_slot = _normalize_gun_slot(normalized_gun_slot)
	if previous_gun_slot != _gun_slot:
		_emit_gun_slot_changed()
	return true


func _normalize_gun_slot(slot_data: Dictionary) -> Dictionary:
	var item_data_path: String = String(slot_data.get("item_data_path", "")).strip_edges()
	if item_data_path.is_empty():
		return {}
	if not _is_gun_item_path(item_data_path):
		return {}
	return {
		"item_data_path": item_data_path,
		"quantity": 1
	}


func _is_gun_item_path(item_data_path: String) -> bool:
	var item_data: Resource = _resolve_item_data(item_data_path)
	return item_data is GunItemData


func _emit_gun_slot_changed() -> void:
	if _suppress_signals:
		return
	gun_slot_changed.emit()
