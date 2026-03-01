class_name InventoryUi
extends Control

@export var columns: int = 4
@export var slot_size: Vector2 = Vector2(72.0, 72.0)
@export var show_quantity: bool = true
@export var empty_slot_text: String = "Empty"

@onready var _slots_grid: GridContainer = $Panel/Margin/VBox/SlotsGrid

var _inventory: Inventory
var _icon_cache: Dictionary = {}


func _ready() -> void:
	if _slots_grid != null:
		_slots_grid.columns = maxi(columns, 1)
	refresh_view()


func _exit_tree() -> void:
	_disconnect_inventory_signals()


func set_inventory_source(source_inventory: Inventory) -> void:
	if _inventory == source_inventory:
		refresh_view()
		return
	_disconnect_inventory_signals()
	_inventory = source_inventory
	_connect_inventory_signals()
	refresh_view()


func clear_inventory_source() -> void:
	set_inventory_source(null)


func refresh_view() -> void:
	if _slots_grid == null:
		return
	_slots_grid.columns = maxi(columns, 1)
	_clear_slots_grid()

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
	if not _inventory.money_changed.is_connected(_on_money_changed):
		_inventory.money_changed.connect(_on_money_changed)


func _disconnect_inventory_signals() -> void:
	if _inventory == null:
		return
	if _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	if _inventory.slot_changed.is_connected(_on_slot_changed):
		_inventory.slot_changed.disconnect(_on_slot_changed)
	if _inventory.money_changed.is_connected(_on_money_changed):
		_inventory.money_changed.disconnect(_on_money_changed)


func _on_inventory_changed() -> void:
	refresh_view()


func _on_slot_changed(_slot_index: int) -> void:
	refresh_view()


func _on_money_changed(_new_money: int) -> void:
	refresh_view()


func _clear_slots_grid() -> void:
	for child in _slots_grid.get_children():
		child.queue_free()


func _create_slot(slot_index: int, slot_data: Dictionary) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = slot_size
	_slots_grid.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(root_vbox)

	if slot_data.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "[%d] %s" % [slot_index, empty_slot_text]
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root_vbox.add_child(empty_label)
		return

	var item_id: String = String(slot_data.get("item_id", ""))
	var quantity: int = int(slot_data.get("quantity", 0))
	var metadata_variant: Variant = slot_data.get("metadata", {})
	var metadata: Dictionary = {}
	if typeof(metadata_variant) == TYPE_DICTIONARY:
		metadata = (metadata_variant as Dictionary).duplicate(true)

	var display_name: String = String(metadata.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = item_id

	var icon: Texture2D = _resolve_icon_from_metadata(metadata.get("icon", null))
	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(slot_size.x - 16.0, slot_size.y * 0.55)
		root_vbox.add_child(icon_rect)
	else:
		var text_label: Label = Label.new()
		text_label.text = display_name
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root_vbox.add_child(text_label)

	var footer_label: Label = Label.new()
	var quantity_text: String = "x%d" % maxi(quantity, 0)
	if show_quantity:
		footer_label.text = "%s %s" % [display_name, quantity_text] if icon != null else quantity_text
	else:
		footer_label.text = display_name if icon != null else ""
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(footer_label)


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


func _resolve_icon_from_metadata(icon_variant: Variant) -> Texture2D:
	if icon_variant is Texture2D:
		return icon_variant as Texture2D

	if typeof(icon_variant) != TYPE_STRING:
		return null

	var icon_path: String = String(icon_variant).strip_edges()
	if icon_path.is_empty():
		return null

	if _icon_cache.has(icon_path):
		var cached_variant: Variant = _icon_cache.get(icon_path)
		if cached_variant is Texture2D:
			return cached_variant as Texture2D
		return null

	var loaded_resource: Resource = load(icon_path)
	if loaded_resource is Texture2D:
		var texture: Texture2D = loaded_resource as Texture2D
		_icon_cache[icon_path] = texture
		return texture
	_icon_cache[icon_path] = null
	return null
