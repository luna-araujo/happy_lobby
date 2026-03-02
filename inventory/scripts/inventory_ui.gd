class_name InventoryUi
extends Control

signal item_use_requested(slot_index: int, item_data_path: String, quantity: int)
signal item_drop_requested(source_ui: InventoryUi, slot_index: int, item_data_path: String, quantity: int)
signal item_split_requested(source_ui: InventoryUi, slot_index: int, quantity: int)
signal external_drop_requested(source_ui: InventoryUi, from_slot: int, target_ui: InventoryUi, to_slot: int)
signal gun_slot_drop_requested(from_slot: int)
signal gun_slot_unequip_requested
signal item_inspect_requested(item_data_path: String)

@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(72.0, 72.0)
@export var show_quantity: bool = true
@export var empty_slot_text: String = "Empty"
@export var is_read_only: bool = false
@export var is_player_inventory: bool = true
@export var owner_name: String = ""
@export var container_name: String = ""
@export var allow_drag_out: bool = true
@export var allow_drop_in: bool = true
@export var show_gun_slot: bool = true
@export var gun_slot_interactive: bool = true

@onready var _title_label: Label = %TitleLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _gun_section: VBoxContainer = %GunSection
@onready var _gun_slot_container: HBoxContainer = %GunSlotContainer
@onready var _slots_grid: GridContainer = %SlotsGrid
@onready var _context_menu: PopupMenu = %ContextMenu

var _inventory: Inventory
var _avatar_inventory: Inventory
var _item_data_cache: Dictionary = {}
var _context_slot_index: int = -1

const CONTEXT_USE: int = 0
const CONTEXT_DROP: int = 1
const CONTEXT_EQUIP: int = 2
const CONTEXT_INSPECT: int = 3
const CONTEXT_SPLIT: int = 4


func _ready() -> void:
	if _slots_grid != null:
		_slots_grid.columns = maxi(columns, 1)
	_refresh_title()
	_setup_context_menu()
	refresh_view()


func _exit_tree() -> void:
	_disconnect_inventory_signals()


func set_inventory_source(source_inventory: Inventory) -> void:
	if _inventory == source_inventory:
		refresh_view()
		return
	_disconnect_inventory_signals()
	_inventory = source_inventory
	_avatar_inventory = null
	if source_inventory != null and source_inventory.has_method("get_gun_slot"):
		_avatar_inventory = source_inventory
	_connect_inventory_signals()
	refresh_view()


func clear_inventory_source() -> void:
	set_inventory_source(null)


func set_inventory_context(is_player: bool, owner: String, container: String, read_only: bool = false) -> void:
	is_player_inventory = is_player
	owner_name = owner
	container_name = container
	is_read_only = read_only
	_refresh_title()


func set_drag_permissions(can_drag_out: bool, can_drop_in: bool) -> void:
	allow_drag_out = can_drag_out
	allow_drop_in = can_drop_in


func set_show_gun_slot(show: bool) -> void:
	show_gun_slot = show
	_refresh_gun_slot_view()


func set_gun_slot_interactive(can_interact: bool) -> void:
	gun_slot_interactive = can_interact
	_refresh_gun_slot_view()


func refresh_view() -> void:
	if _slots_grid == null:
		return
	_slots_grid.columns = maxi(columns, 1)
	_clear_slots_grid()
	_refresh_gun_slot_view()
	_refresh_money_label()

	if _inventory == null:
		_create_placeholder_slot("No inventory")
		return

	var slots: Array[Dictionary] = _inventory.get_slots()
	if slots.is_empty():
		_create_placeholder_slot("No slots")
		return

	for slot_index in range(slots.size()):
		var slot_data: Dictionary = slots[slot_index]
		_create_slot(slot_index, slot_data)


func _connect_inventory_signals() -> void:
	if _inventory == null:
		return
	if not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)
	if not _inventory.slot_changed.is_connected(_on_slot_changed):
		_inventory.slot_changed.connect(_on_slot_changed)
	if _avatar_inventory != null:
		if not _avatar_inventory.gun_slot_changed.is_connected(_on_gun_slot_changed):
			_avatar_inventory.gun_slot_changed.connect(_on_gun_slot_changed)
	if not _inventory.money_changed.is_connected(_on_money_changed):
		_inventory.money_changed.connect(_on_money_changed)


func _disconnect_inventory_signals() -> void:
	if _inventory == null:
		return
	if _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	if _inventory.slot_changed.is_connected(_on_slot_changed):
		_inventory.slot_changed.disconnect(_on_slot_changed)
	if _avatar_inventory != null:
		if _avatar_inventory.gun_slot_changed.is_connected(_on_gun_slot_changed):
			_avatar_inventory.gun_slot_changed.disconnect(_on_gun_slot_changed)
	if _inventory.money_changed.is_connected(_on_money_changed):
		_inventory.money_changed.disconnect(_on_money_changed)
	_avatar_inventory = null


func _on_inventory_changed() -> void:
	refresh_view()


func _on_slot_changed(_slot_index: int) -> void:
	refresh_view()


func _on_gun_slot_changed() -> void:
	_refresh_gun_slot_view()


func _on_money_changed(_new_money: int) -> void:
	_refresh_money_label()


func _clear_slots_grid() -> void:
	for child in _slots_grid.get_children():
		child.queue_free()


func _refresh_gun_slot_view() -> void:
	if _gun_section == null or _gun_slot_container == null:
		return
	for child in _gun_slot_container.get_children():
		child.queue_free()

	var should_show: bool = show_gun_slot and _avatar_inventory != null
	_gun_section.visible = should_show
	if not should_show:
		return

	var gun_slot_data: Dictionary = _avatar_inventory.get_gun_slot()
	var item_data_path: String = String(gun_slot_data.get("item_data_path", "")).strip_edges()
	var item_data: Resource = _resolve_item_data(item_data_path)
	var display_name: String = "Gun"
	var icon: Texture2D = null
	if item_data != null:
		var display_name_variant: Variant = item_data.get("display_name")
		display_name = String(display_name_variant).strip_edges()
		if display_name.is_empty():
			var item_id_variant: Variant = item_data.get("item_id")
			display_name = String(item_id_variant).strip_edges()
		var icon_variant: Variant = item_data.get("icon")
		if icon_variant is Texture2D:
			icon = icon_variant as Texture2D
	if display_name.is_empty():
		display_name = "Gun"

	var gun_slot: InventorySlot = InventorySlot.new()
	_gun_slot_container.add_child(gun_slot)
	var gun_slot_size: Vector2 = Vector2(maxf(slot_size.x, 96.0), maxf(slot_size.y, 96.0))
	gun_slot.configure(self, -1, gun_slot_data, display_name, icon, false, "Drop gun item here", gun_slot_size)


func _create_slot(slot_index: int, slot_data: Dictionary) -> void:
	var item_data_path: String = String(slot_data.get("item_data_path", "")).strip_edges()
	var item_data: Resource = _resolve_item_data(item_data_path)
	var display_name: String = ""
	var icon: Texture2D = null

	if item_data != null:
		var display_name_variant: Variant = item_data.get("display_name")
		display_name = String(display_name_variant).strip_edges()
		if display_name.is_empty():
			var item_id_variant: Variant = item_data.get("item_id")
			display_name = String(item_id_variant).strip_edges()
		var icon_variant: Variant = item_data.get("icon")
		if icon_variant is Texture2D:
			icon = icon_variant as Texture2D
	if display_name.is_empty():
		display_name = item_data_path.get_file().get_basename()
	if display_name.is_empty():
		display_name = "Unknown Item"

	var slot: InventorySlot = InventorySlot.new()
	_slots_grid.add_child(slot)
	slot.configure(self, slot_index, slot_data, display_name, icon, show_quantity, empty_slot_text, slot_size)


func _create_placeholder_slot(message: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = slot_size
	_slots_grid.add_child(panel)

	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)


func _resolve_item_data(item_data_path: String) -> Resource:
	if item_data_path.is_empty():
		return null

	if _item_data_cache.has(item_data_path):
		var cached_variant: Variant = _item_data_cache.get(item_data_path)
		if cached_variant is Resource:
			return cached_variant as Resource
		return null

	var loaded_resource: Resource = load(item_data_path)
	if loaded_resource != null:
		_item_data_cache[item_data_path] = loaded_resource
		return loaded_resource
	_item_data_cache[item_data_path] = null
	return null


func open_context_menu(slot_index: int) -> void:
	if _context_menu == null:
		return
	if _inventory == null:
		return
	var slot_data: Dictionary = _inventory.get_slot(slot_index)
	if slot_data.is_empty():
		return
	var item_data_path: String = String(slot_data.get("item_data_path", "")).strip_edges()
	var quantity: int = int(slot_data.get("quantity", 0))
	var item_data: Resource = _resolve_item_data(item_data_path)
	var is_gun_item: bool = item_data is GunItemData
	var has_use_action: bool = _item_has_use_action(item_data)
	var can_split_stack: bool = _can_split_stack(slot_index, quantity)
	_context_slot_index = slot_index
	_context_menu.clear()
	if not is_read_only and is_player_inventory and has_use_action:
		_context_menu.add_item("Use", CONTEXT_USE)
	if not is_read_only and is_gun_item and _avatar_inventory != null and gun_slot_interactive:
		_context_menu.add_item("Equip", CONTEXT_EQUIP)
	_context_menu.add_item("Inspect", CONTEXT_INSPECT)
	if not is_read_only and can_split_stack:
		_context_menu.add_item("Split", CONTEXT_SPLIT)
	if not is_read_only:
		_context_menu.add_item("Drop", CONTEXT_DROP)
	var screen_pos: Vector2i = DisplayServer.mouse_get_position()
	_context_menu.popup(Rect2i(screen_pos, Vector2i(1, 1)))


func handle_drop(from_slot: int, to_slot: int) -> void:
	if is_read_only:
		return
	if _inventory == null:
		return
	if from_slot == to_slot:
		return
	var from_data: Dictionary = _inventory.get_slot(from_slot)
	if from_data.is_empty():
		return
	var to_data: Dictionary = _inventory.get_slot(to_slot)
	if to_data.is_empty():
		_inventory.swap_slots(from_slot, to_slot)
		return
	if String(from_data.get("item_data_path", "")) == String(to_data.get("item_data_path", "")):
		_inventory.merge_stack(from_slot, to_slot)
		return
	_inventory.swap_slots(from_slot, to_slot)


func can_accept_drop_data(payload: Dictionary, to_slot: int) -> bool:
	if is_read_only:
		return false
	if not allow_drop_in:
		return false
	if typeof(payload) != TYPE_DICTIONARY:
		return false
	if not payload.has("source_ui") or not payload.has("from_slot"):
		return false

	var source_variant: Variant = payload.get("source_ui")
	if not (source_variant is InventoryUi):
		return false
	var source_ui: InventoryUi = source_variant as InventoryUi
	if source_ui == null:
		return false
	if not source_ui.allow_drag_out:
		return false

	var from_slot: int = int(payload.get("from_slot", -1))
	if from_slot < 0:
		return false

	if to_slot == -1:
		if not show_gun_slot:
			return false
		if not gun_slot_interactive:
			return false
		if _avatar_inventory == null:
			return false
		if source_ui != self:
			return false
		var from_data: Dictionary = _inventory.get_slot(from_slot)
		if from_data.is_empty():
			return false
		var item_data_path: String = String(from_data.get("item_data_path", "")).strip_edges()
		var item_data: Resource = _resolve_item_data(item_data_path)
		return item_data is GunItemData

	if source_ui == self:
		return from_slot != to_slot
	return true


func handle_drop_payload(payload: Dictionary, to_slot: int) -> void:
	if not can_accept_drop_data(payload, to_slot):
		return

	var source_variant: Variant = payload.get("source_ui")
	var source_ui: InventoryUi = source_variant as InventoryUi
	var from_slot: int = int(payload.get("from_slot", -1))
	if source_ui == null or from_slot < 0:
		return

	if to_slot == -1:
		if source_ui != self:
			return
		gun_slot_drop_requested.emit(from_slot)
		return

	if source_ui == self:
		handle_drop(from_slot, to_slot)
		return
	external_drop_requested.emit(source_ui, from_slot, self, to_slot)


func handle_failed_drag_payload(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	if not payload.has("source_ui") or not payload.has("from_slot"):
		return
	var source_variant: Variant = payload.get("source_ui")
	if not (source_variant is InventoryUi):
		return
	var source_ui: InventoryUi = source_variant as InventoryUi
	if source_ui == null:
		return
	if not source_ui.allow_drag_out:
		return
	if source_ui.is_read_only:
		return
	if source_ui._inventory == null:
		return
	var from_slot: int = int(payload.get("from_slot", -1))
	if from_slot < 0:
		return
	var source_slot: Dictionary = source_ui._inventory.get_slot(from_slot)
	if source_slot.is_empty():
		return
	var item_data_path: String = String(source_slot.get("item_data_path", "")).strip_edges()
	if item_data_path.is_empty():
		return
	item_drop_requested.emit(source_ui, from_slot, item_data_path, 1)


func handle_special_slot_right_click(slot_index: int) -> void:
	if slot_index != -1:
		return
	if is_read_only:
		return
	if not show_gun_slot:
		return
	if not gun_slot_interactive:
		return
	if _inventory == null:
		return
	if _avatar_inventory == null:
		return
	if _avatar_inventory.is_gun_slot_empty():
		return
	gun_slot_unequip_requested.emit()


func _setup_context_menu() -> void:
	if _context_menu == null:
		return
	if not _context_menu.id_pressed.is_connected(_on_context_action_selected):
		_context_menu.id_pressed.connect(_on_context_action_selected)


func _on_context_action_selected(action_id: int) -> void:
	if _inventory == null:
		return
	if _context_slot_index < 0:
		return
	var slot_data: Dictionary = _inventory.get_slot(_context_slot_index)
	if slot_data.is_empty():
		return
	var item_data_path: String = String(slot_data.get("item_data_path", ""))
	var quantity: int = int(slot_data.get("quantity", 0))

	match action_id:
		CONTEXT_EQUIP:
			if is_read_only:
				return
			var resolved_item_data_path: String = item_data_path.strip_edges()
			if resolved_item_data_path.is_empty():
				return
			var item_data: Resource = _resolve_item_data(resolved_item_data_path)
			if not (item_data is GunItemData):
				return
			if _avatar_inventory == null:
				return
			if not gun_slot_interactive:
				return
			gun_slot_drop_requested.emit(_context_slot_index)
		CONTEXT_INSPECT:
			var resolved_item_data_path: String = item_data_path.strip_edges()
			if resolved_item_data_path.is_empty():
				return
			item_inspect_requested.emit(resolved_item_data_path)
		CONTEXT_USE:
			if is_read_only:
				return
			if not is_player_inventory:
				return
			var resolved_item_data_path: String = item_data_path.strip_edges()
			if resolved_item_data_path.is_empty():
				return
			var item_data: Resource = _resolve_item_data(resolved_item_data_path)
			if not _item_has_use_action(item_data):
				return
			item_use_requested.emit(_context_slot_index, item_data_path, quantity)
		CONTEXT_DROP:
			if is_read_only:
				return
			var resolved_item_data_path: String = item_data_path.strip_edges()
			if resolved_item_data_path.is_empty():
				return
			item_drop_requested.emit(self, _context_slot_index, resolved_item_data_path, 1)
		CONTEXT_SPLIT:
			if is_read_only:
				return
			if quantity <= 1:
				return
			var split_quantity: int = _resolve_default_split_quantity(quantity)
			if split_quantity <= 0:
				return
			item_split_requested.emit(self, _context_slot_index, split_quantity)


func _item_has_use_action(item_data: Resource) -> bool:
	if item_data == null:
		return false
	if not item_data.has_method("has_use_action"):
		return false
	var has_use_variant: Variant = item_data.call("has_use_action")
	if typeof(has_use_variant) != TYPE_BOOL:
		return false
	return bool(has_use_variant)


func _can_split_stack(slot_index: int, quantity: int) -> bool:
	if _inventory == null:
		return false
	if slot_index < 0:
		return false
	if quantity <= 1:
		return false
	return _resolve_default_split_quantity(quantity) > 0


func _resolve_default_split_quantity(stack_quantity: int) -> int:
	if stack_quantity <= 1:
		return 0
	return maxi(stack_quantity / 2, 1)


func _refresh_title() -> void:
	if _title_label == null:
		return
	if is_player_inventory:
		var resolved_owner: String = owner_name.strip_edges()
		if resolved_owner.is_empty():
			_title_label.text = "Player Inventory"
		else:
			_title_label.text = "%s's inventory" % resolved_owner
		return
	var resolved_container: String = container_name.strip_edges()
	if resolved_container.is_empty():
		_title_label.text = "Container"
	else:
		_title_label.text = resolved_container


func _refresh_money_label() -> void:
	if _money_label == null:
		return
	if _inventory == null:
		_money_label.text = "Gold: --"
		return
	_money_label.text = "Gold: %d" % _inventory.get_money()
