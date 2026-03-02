class_name InventorySlot
extends PanelContainer

var owner_ui: InventoryUi
var slot_index: int = -1
var slot_data: Dictionary = {}
var display_name: String = ""
var icon: Texture2D
var show_quantity: bool = true
var empty_slot_text: String = "Empty"
var _slot_size: Vector2 = Vector2(72.0, 72.0)
var _active_drag_payload: Dictionary = {}


func configure(
		new_owner: InventoryUi,
		new_slot_index: int,
		new_slot_data: Dictionary,
		new_display_name: String,
		new_icon: Texture2D,
		new_show_quantity: bool,
		new_empty_slot_text: String,
		slot_size: Vector2
) -> void:
	owner_ui = new_owner
	slot_index = new_slot_index
	slot_data = new_slot_data.duplicate(true)
	display_name = new_display_name
	icon = new_icon
	show_quantity = new_show_quantity
	empty_slot_text = new_empty_slot_text
	_slot_size = Vector2(maxf(slot_size.x, 48.0), maxf(slot_size.y, 48.0))
	custom_minimum_size = _slot_size
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_FILL
	_rebuild_contents()


func _gui_input(event: InputEvent) -> void:
	if owner_ui == null:
		return
	if slot_data.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if slot_index < 0:
				if owner_ui.has_method("handle_special_slot_right_click"):
					owner_ui.call("handle_special_slot_right_click", slot_index)
				return
			owner_ui.open_context_menu(slot_index)


func _get_drag_data(_position: Vector2) -> Variant:
	if owner_ui == null:
		return null
	if owner_ui.is_read_only:
		return null
	if slot_index < 0:
		return null
	if not owner_ui.allow_drag_out:
		return null
	if slot_data.is_empty():
		return null

	var preview: Control = _build_drag_preview()
	if preview != null:
		set_drag_preview(preview)

	_active_drag_payload = {
		"source_ui": owner_ui,
		"from_slot": slot_index
	}
	return _active_drag_payload


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if owner_ui == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data as Dictionary
	if owner_ui.has_method("can_accept_drop_data"):
		return bool(owner_ui.call("can_accept_drop_data", payload, slot_index))
	return false


func _drop_data(_position: Vector2, data: Variant) -> void:
	if owner_ui == null:
		return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = data as Dictionary
	if owner_ui.has_method("handle_drop_payload"):
		owner_ui.call("handle_drop_payload", payload, slot_index)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _active_drag_payload.is_empty():
		return
	var payload: Dictionary = _active_drag_payload.duplicate(true)
	_active_drag_payload.clear()
	if is_drag_successful():
		return
	if owner_ui == null:
		return
	if owner_ui.has_method("handle_failed_drag_payload"):
		owner_ui.call("handle_failed_drag_payload", payload)


func _build_drag_preview() -> Control:
	var side: float = maxf(minf(_slot_size.x, _slot_size.y), 48.0)
	var preview_size: Vector2 = Vector2(side, side)

	var preview: PanelContainer = PanelContainer.new()
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	preview.add_child(margin)

	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon
		var preview_icon_size: float = maxf(side - 16.0, 24.0)
		icon_rect.custom_minimum_size = Vector2(preview_icon_size, preview_icon_size)
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(icon_rect)
	else:
		var label: Label = Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_child(label)

	return preview


func _rebuild_contents() -> void:
	for child in get_children():
		child.queue_free()

	var content_root: Control = Control.new()
	_set_mouse_passthrough(content_root)
	content_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_root.offset_left = 6.0
	content_root.offset_top = 6.0
	content_root.offset_right = -6.0
	content_root.offset_bottom = -6.0
	add_child(content_root)

	if slot_data.is_empty():
		var empty_label: Label = Label.new()
		_set_mouse_passthrough(empty_label)
		if slot_index < 0:
			empty_label.text = empty_slot_text
		else:
			empty_label.text = "[%d] %s" % [slot_index, empty_slot_text]
		empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		empty_label.clip_text = true
		content_root.add_child(empty_label)
		return

	var footer_height: float = 18.0
	var body: Control = Control.new()
	_set_mouse_passthrough(body)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_bottom = -footer_height
	content_root.add_child(body)

	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		_set_mouse_passthrough(icon_rect)
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon
		body.add_child(icon_rect)
	else:
		var text_label: Label = Label.new()
		_set_mouse_passthrough(text_label)
		text_label.text = display_name
		text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		text_label.clip_text = true
		body.add_child(text_label)

	var footer_label: Label = Label.new()
	_set_mouse_passthrough(footer_label)
	footer_label.anchor_top = 1.0
	footer_label.anchor_right = 1.0
	footer_label.anchor_bottom = 1.0
	footer_label.offset_top = -footer_height
	var quantity: int = int(slot_data.get("quantity", 0))
	var quantity_text: String = "x%d" % maxi(quantity, 0)
	if show_quantity:
		footer_label.text = quantity_text
	else:
		footer_label.text = display_name if icon != null else ""
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer_label.clip_text = true
	content_root.add_child(footer_label)


func _set_mouse_passthrough(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
