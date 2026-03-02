class_name PlayerUi
extends CanvasLayer

@export var rebind_interval_seconds: float = 0.25
@export var neo_world_group_name: StringName = &"NeoWorld"
@export var interaction_prompt_fade_in_seconds: float = 0.12
@export var interaction_prompt_fade_out_seconds: float = 0.16

@onready var _root: Control = $Root
@onready var _hud_panel: PanelContainer = $Root/BottomLeftHud
@onready var _name_label: Label = $Root/BottomLeftHud/Margin/VBox/PlayerName
@onready var _hp_bar: ProgressBar = $Root/BottomLeftHud/Margin/VBox/HpBar
@onready var _status_list: VBoxContainer = $Root/BottomLeftHud/Margin/VBox/StatusList
@onready var _inventory_ui: InventoryUi = $Root/InventoryUi
@onready var _loot_inventory_ui: InventoryUi = $Root/LootInventoryUi
@onready var _loot_inventory_close_button: Button = $Root/LootInventoryCloseButton
@onready var _interaction_prompt_panel: PanelContainer = $Root/InteractionPrompt
@onready var _interaction_prompt_label: Label = $Root/InteractionPrompt/Margin/PromptLabel
@onready var _item_inspect_popup: PanelContainer = $Root/ItemInspectPopup
@onready var _item_inspect_title_label: Label = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemTitleLabel
@onready var _item_inspect_icon: TextureRect = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemIcon
@onready var _item_inspect_rarity_label: Label = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemRarityLabel
@onready var _item_inspect_description_label: Label = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemDescriptionLabel
@onready var _item_inspect_stats_section: VBoxContainer = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemStatsSection
@onready var _item_inspect_stats_label: Label = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemStatsSection/ItemStatsLabel
@onready var _item_inspect_close_button: Button = $Root/ItemInspectPopup/InspectMargin/InspectVBox/ItemInspectCloseButton
@onready var _inspector: PlayerUiInspector = $Inspector

var _bound_avatar: Avatar
var _bound_combat: CharacterCombat
var _bound_inventory: Inventory
var _player_characters_root: Node
var _rebind_timer: float = 0.0
var _status_labels: Dictionary = {}
var _active_loot_npc_id: int = -1
var _active_loot_chest_id: int = -1
var _active_inspect_avatar_id: int = -1
var _inspected_avatar: Avatar
var _interaction_prompt_target_visible: bool = false
var _interaction_prompt_tween: Tween
var _item_inspect_item_data_cache: Dictionary = {}
var _mouse_locked_before_loot_open: bool = false


func _ready() -> void:
	layer = 90
	_configure_inventory_ui()
	_initialize_interaction_prompt_state()
	_initialize_inspect_panel_state()
	_initialize_item_inspect_popup_state()
	_connect_session_signals()
	_set_panel_visible(false)
	_player_characters_root = _resolve_player_characters_root()
	_attempt_bind_local_avatar(true)


func _process(delta: float) -> void:
	_rebind_timer -= maxf(delta, 0.0)
	if _rebind_timer <= 0.0:
		_rebind_timer = maxf(rebind_interval_seconds, 0.05)
		_attempt_bind_local_avatar(false)

	if _bound_avatar != null and is_instance_valid(_bound_avatar):
		_refresh_identity()
		_validate_inspected_avatar()
	if _bound_combat != null and is_instance_valid(_bound_combat):
		_refresh_status()


func set_player_avatar(avatar: Avatar) -> void:
	if _bound_avatar == avatar:
		_refresh_all()
		return

	_unbind_avatar()

	if avatar == null:
		_set_panel_visible(false)
		return
	if not is_instance_valid(avatar):
		_set_panel_visible(false)
		return

	_bound_avatar = avatar
	_bound_combat = avatar.combat
	_bound_inventory = avatar.inventory

	if not _bound_avatar.tree_exiting.is_connected(_on_bound_avatar_tree_exiting):
		_bound_avatar.tree_exiting.connect(_on_bound_avatar_tree_exiting)
	if _bound_combat != null:
		if not _bound_combat.state_changed.is_connected(_on_state_changed):
			_bound_combat.state_changed.connect(_on_state_changed)
		if not _bound_combat.hp_changed.is_connected(_on_hp_changed):
			_bound_combat.hp_changed.connect(_on_hp_changed)
	if _inventory_ui != null:
		_inventory_ui.set_inventory_source(avatar.inventory)
		_inventory_ui.set_inventory_context(true, _resolve_display_name(), "", false)
		_inventory_ui.set_drag_permissions(true, true)
		var has_gun_slot_support: bool = _bound_inventory != null and _bound_inventory.has_method("get_gun_slot")
		_inventory_ui.set_show_gun_slot(has_gun_slot_support)
		_inventory_ui.set_gun_slot_interactive(has_gun_slot_support)
	if _inspector != null:
		_inspector.set_local_avatar(_bound_avatar)

	_set_panel_visible(true)
	_refresh_all()


func clear_player_avatar() -> void:
	set_player_avatar(null)


func _exit_tree() -> void:
	_unbind_avatar()


func _attempt_bind_local_avatar(force_refresh: bool) -> void:
	if _bound_avatar != null and is_instance_valid(_bound_avatar):
		if _is_local_avatar(_bound_avatar):
			if force_refresh:
				_refresh_all()
			return

	if _player_characters_root == null or not is_instance_valid(_player_characters_root):
		_player_characters_root = _resolve_player_characters_root()
	if _player_characters_root == null:
		clear_player_avatar()
		return

	var resolved_avatar: Avatar = _find_local_avatar_in_root(_player_characters_root)
	if resolved_avatar == null:
		clear_player_avatar()
		return
	set_player_avatar(resolved_avatar)


func _connect_session_signals() -> void:
	if SessionManager == null:
		return
	if not SessionManager.has_signal("lobby_left"):
		return
	if not SessionManager.lobby_left.is_connected(_on_session_lobby_left):
		SessionManager.lobby_left.connect(_on_session_lobby_left)


func _on_session_lobby_left() -> void:
	clear_player_avatar()


func _find_local_avatar_in_root(root_node: Node) -> Avatar:
	var local_peer_id: int = _get_local_peer_id()
	if local_peer_id > 0:
		for child in root_node.get_children():
			if child is Avatar:
				var candidate_avatar: Avatar = child as Avatar
				if candidate_avatar.player_id == local_peer_id:
					return candidate_avatar

	for child in root_node.get_children():
		if child is Avatar:
			return child as Avatar
	return null


func _is_local_avatar(avatar: Avatar) -> bool:
	if avatar == null or not is_instance_valid(avatar):
		return false
	var local_peer_id: int = _get_local_peer_id()
	if local_peer_id <= 0:
		return false
	return avatar.player_id == local_peer_id


func _resolve_player_characters_root() -> Node:
	var world_from_group: Node = get_tree().get_first_node_in_group(String(neo_world_group_name))
	if world_from_group != null:
		var group_player_chars: Node = world_from_group.get_node_or_null("PlayerCharacters")
		if group_player_chars != null:
			return group_player_chars

	var world_by_name: Node = get_tree().root.find_child("NeoWorld", true, false)
	if world_by_name != null:
		var named_player_chars: Node = world_by_name.get_node_or_null("PlayerCharacters")
		if named_player_chars != null:
			return named_player_chars

	return null


func _get_local_peer_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return -1
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return -1
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return -1
	return multiplayer.get_unique_id()


func _unbind_avatar() -> void:
	if _bound_combat != null and is_instance_valid(_bound_combat):
		if _bound_combat.state_changed.is_connected(_on_state_changed):
			_bound_combat.state_changed.disconnect(_on_state_changed)
		if _bound_combat.hp_changed.is_connected(_on_hp_changed):
			_bound_combat.hp_changed.disconnect(_on_hp_changed)

	if _bound_avatar != null and is_instance_valid(_bound_avatar):
		if _bound_avatar.tree_exiting.is_connected(_on_bound_avatar_tree_exiting):
			_bound_avatar.tree_exiting.disconnect(_on_bound_avatar_tree_exiting)

	_bound_avatar = null
	_bound_combat = null
	_bound_inventory = null
	if _inspector != null:
		_inspector.clear_local_avatar()
	if _inventory_ui != null:
		_inventory_ui.clear_inventory_source()
	close_loot_inventory()
	_close_avatar_inspect_inventory_view()
	_clear_inspect_target()
	_close_item_inspect_popup()
	set_interaction_prompt_visible(false)


func _refresh_all() -> void:
	_refresh_identity()
	_refresh_health()
	_refresh_status()


func _refresh_identity() -> void:
	if _name_label == null:
		return
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		_name_label.text = "No Player"
		return
	var resolved_name: String = _resolve_display_name()
	_name_label.text = resolved_name


func _resolve_display_name() -> String:
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		return "No Player"
	var resolved_name: String = _bound_avatar.display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Player_%d" % _bound_avatar.player_id
	return resolved_name


func _refresh_health() -> void:
	if _hp_bar == null:
		return
	if _bound_combat == null or not is_instance_valid(_bound_combat):
		_hp_bar.max_value = 1
		_hp_bar.value = 0
		return
	var safe_max: int = maxi(_bound_combat.max_hp, 1)
	var safe_hp: int = clampi(_bound_combat.hp, 0, safe_max)
	_hp_bar.max_value = safe_max
	_hp_bar.value = safe_hp


func _refresh_status() -> void:
	if _status_list == null:
		return
	if _bound_combat == null or not is_instance_valid(_bound_combat):
		_clear_status_labels()
		return

	_clear_status_labels()
	match _bound_combat.state:
		CharacterCombat.CombatState.DEAD:
			_set_status_visible("DEAD", true, Color(0.95, 0.25, 0.25))
		CharacterCombat.CombatState.STUNNED:
			_set_status_visible("STUNNED", true, Color(0.98, 0.68, 0.18))
		CharacterCombat.CombatState.PARRYING:
			_set_status_visible("PARRYING", true, Color(0.8, 0.8, 1.0))
		_:
			pass


func _set_panel_visible(is_visible: bool) -> void:
	if _root != null:
		_root.visible = is_visible
	if _hud_panel != null:
		_hud_panel.visible = is_visible


func _on_state_changed(_previous_state: int, _new_state: int) -> void:
	_refresh_status()


func _on_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_refresh_health()


func _set_status_visible(status_key: String, is_visible: bool, status_color: Color) -> void:
	if _status_list == null:
		return

	var existing: Variant = _status_labels.get(status_key, null)
	var status_label: Label = existing as Label
	if is_visible:
		if status_label == null or not is_instance_valid(status_label):
			status_label = Label.new()
			status_label.text = status_key
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_status_list.add_child(status_label)
			_status_labels[status_key] = status_label
		status_label.visible = true
		status_label.modulate = status_color
		return

	if status_label != null and is_instance_valid(status_label):
		status_label.queue_free()
	_status_labels.erase(status_key)


func _clear_status_labels() -> void:
	for status_label in _status_labels.values():
		var label: Label = status_label as Label
		if label != null and is_instance_valid(label):
			label.queue_free()
	_status_labels.clear()


func _on_bound_avatar_tree_exiting() -> void:
	clear_player_avatar()


func open_loot_inventory_for_npc(npc_id: int, source_inventory: Inventory, container_name: String) -> void:
	if _loot_inventory_ui == null:
		return
	_clear_inspect_target()
	if UIManager != null:
		_mouse_locked_before_loot_open = UIManager.mouse_locked
		UIManager.release_mouse()
	else:
		_mouse_locked_before_loot_open = false
	_active_loot_npc_id = npc_id
	_active_loot_chest_id = -1
	_loot_inventory_ui.visible = true
	_set_loot_inventory_close_button_visible(true)
	_loot_inventory_ui.set_inventory_source(source_inventory)
	_loot_inventory_ui.set_inventory_context(false, "", container_name, false)
	_loot_inventory_ui.set_drag_permissions(true, false)
	_loot_inventory_ui.set_show_gun_slot(false)
	_loot_inventory_ui.set_gun_slot_interactive(false)


func open_loot_inventory_for_chest(chest_id: int, source_inventory: Inventory, container_name: String) -> void:
	if _loot_inventory_ui == null:
		return
	_clear_inspect_target()
	if UIManager != null:
		_mouse_locked_before_loot_open = UIManager.mouse_locked
		UIManager.release_mouse()
	else:
		_mouse_locked_before_loot_open = false
	_active_loot_npc_id = -1
	_active_loot_chest_id = chest_id
	_loot_inventory_ui.visible = true
	_set_loot_inventory_close_button_visible(true)
	_loot_inventory_ui.set_inventory_source(source_inventory)
	_loot_inventory_ui.set_inventory_context(false, "", container_name, false)
	_loot_inventory_ui.set_drag_permissions(true, true)
	_loot_inventory_ui.set_show_gun_slot(false)
	_loot_inventory_ui.set_gun_slot_interactive(false)


func close_loot_inventory() -> void:
	_active_loot_npc_id = -1
	_active_loot_chest_id = -1
	if _loot_inventory_ui == null:
		_restore_mouse_after_loot_close()
		return
	_loot_inventory_ui.clear_inventory_source()
	_loot_inventory_ui.visible = false
	_set_loot_inventory_close_button_visible(false)
	_restore_mouse_after_loot_close()


func set_interaction_prompt(text: String) -> void:
	if _interaction_prompt_label != null:
		_interaction_prompt_label.text = text
	set_interaction_prompt_visible(true)


func set_interaction_prompt_visible(is_visible: bool) -> void:
	if _interaction_prompt_panel == null:
		return
	if _interaction_prompt_target_visible == is_visible:
		return
	_interaction_prompt_target_visible = is_visible
	_animate_interaction_prompt_visibility(is_visible)


func _initialize_interaction_prompt_state() -> void:
	_interaction_prompt_target_visible = false
	if _interaction_prompt_panel == null:
		return
	_interaction_prompt_panel.visible = false
	_interaction_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _animate_interaction_prompt_visibility(is_visible: bool) -> void:
	if _interaction_prompt_panel == null:
		return
	if _interaction_prompt_tween != null and _interaction_prompt_tween.is_valid():
		_interaction_prompt_tween.kill()
	var fade_duration: float = maxf(
		interaction_prompt_fade_in_seconds if is_visible else interaction_prompt_fade_out_seconds,
		0.0
	)
	if is_visible:
		_interaction_prompt_panel.visible = true
	if is_zero_approx(fade_duration):
		var immediate_alpha: float = 1.0 if is_visible else 0.0
		_interaction_prompt_panel.modulate.a = immediate_alpha
		if not is_visible:
			_interaction_prompt_panel.visible = false
		return
	_interaction_prompt_tween = create_tween()
	_interaction_prompt_tween.set_trans(Tween.TRANS_CUBIC)
	_interaction_prompt_tween.set_ease(Tween.EASE_OUT if is_visible else Tween.EASE_IN)
	var target_alpha: float = 1.0 if is_visible else 0.0
	_interaction_prompt_tween.tween_property(_interaction_prompt_panel, "modulate:a", target_alpha, fade_duration)
	if not is_visible:
		_interaction_prompt_tween.finished.connect(_on_interaction_prompt_fade_out_finished)


func _on_interaction_prompt_fade_out_finished() -> void:
	if _interaction_prompt_panel == null:
		return
	if _interaction_prompt_target_visible:
		return
	_interaction_prompt_panel.visible = false


func _configure_inventory_ui() -> void:
	if _inventory_ui != null:
		_inventory_ui.set_drag_permissions(true, true)
		if not _inventory_ui.external_drop_requested.is_connected(_on_inventory_external_drop_requested):
			_inventory_ui.external_drop_requested.connect(_on_inventory_external_drop_requested)
		if not _inventory_ui.item_inspect_requested.is_connected(_on_item_inspect_requested):
			_inventory_ui.item_inspect_requested.connect(_on_item_inspect_requested)
	if _loot_inventory_ui != null:
		_loot_inventory_ui.visible = false
		_loot_inventory_ui.set_drag_permissions(true, false)
		_loot_inventory_ui.set_show_gun_slot(false)
		_loot_inventory_ui.set_gun_slot_interactive(false)
		if not _loot_inventory_ui.item_inspect_requested.is_connected(_on_item_inspect_requested):
			_loot_inventory_ui.item_inspect_requested.connect(_on_item_inspect_requested)
	_set_loot_inventory_close_button_visible(false)
	if _inspector != null:
		if not _inspector.inspect_target_avatar_selected.is_connected(_on_inspect_target_avatar_selected):
			_inspector.inspect_target_avatar_selected.connect(_on_inspect_target_avatar_selected)
		if not _inspector.inspect_target_inventory_requested.is_connected(_on_inspect_target_inventory_requested):
			_inspector.inspect_target_inventory_requested.connect(_on_inspect_target_inventory_requested)
		if not _inspector.inspect_target_cleared.is_connected(_on_inspect_target_cleared):
			_inspector.inspect_target_cleared.connect(_on_inspect_target_cleared)
	if _inventory_ui != null:
		if not _inventory_ui.gun_slot_drop_requested.is_connected(_on_gun_slot_drop_requested):
			_inventory_ui.gun_slot_drop_requested.connect(_on_gun_slot_drop_requested)
		if not _inventory_ui.gun_slot_unequip_requested.is_connected(_on_gun_slot_unequip_requested):
			_inventory_ui.gun_slot_unequip_requested.connect(_on_gun_slot_unequip_requested)
	if _loot_inventory_close_button != null:
		if not _loot_inventory_close_button.pressed.is_connected(_on_loot_inventory_close_button_pressed):
			_loot_inventory_close_button.pressed.connect(_on_loot_inventory_close_button_pressed)
	if _item_inspect_close_button != null:
		if not _item_inspect_close_button.pressed.is_connected(_on_item_inspect_close_button_pressed):
			_item_inspect_close_button.pressed.connect(_on_item_inspect_close_button_pressed)


func _on_inventory_external_drop_requested(source_ui: InventoryUi, from_slot: int, target_ui: InventoryUi, to_slot: int) -> void:
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		return
	if source_ui == _loot_inventory_ui and target_ui == _inventory_ui:
		if _active_loot_npc_id > 0:
			if not _bound_avatar.has_method("request_loot_transfer"):
				return
			_bound_avatar.call("request_loot_transfer", _active_loot_npc_id, from_slot, to_slot)
			return
		if _active_loot_chest_id != -1:
			if not _bound_avatar.has_method("request_chest_take"):
				return
			_bound_avatar.call("request_chest_take", _active_loot_chest_id, from_slot, to_slot)
		return

	if source_ui == _inventory_ui and target_ui == _loot_inventory_ui:
		if _active_loot_chest_id == -1:
			return
		if not _bound_avatar.has_method("request_chest_store"):
			return
		_bound_avatar.call("request_chest_store", _active_loot_chest_id, from_slot, to_slot)


func _initialize_inspect_panel_state() -> void:
	_active_inspect_avatar_id = -1
	_inspected_avatar = null


func _on_inspect_target_avatar_selected(target_avatar: Avatar) -> void:
	if target_avatar == null:
		_clear_inspect_target()
		return
	if not is_instance_valid(target_avatar):
		_clear_inspect_target()
		return
	_inspected_avatar = target_avatar
	_active_inspect_avatar_id = target_avatar.player_id


func _on_inspect_target_cleared() -> void:
	_clear_inspect_target()


func _on_inspect_target_inventory_requested(target_avatar: Avatar) -> void:
	if target_avatar == null or not is_instance_valid(target_avatar):
		_clear_inspect_target()
		return
	_inspected_avatar = target_avatar
	_active_inspect_avatar_id = target_avatar.player_id
	var target_inventory: Inventory = target_avatar.inventory
	if target_inventory == null:
		_close_avatar_inspect_inventory_view()
		return
	close_loot_inventory()
	_open_avatar_inspect_inventory_view(target_avatar, target_inventory)


func _open_avatar_inspect_inventory_view(target_avatar: Avatar, source_inventory: Inventory) -> void:
	if _loot_inventory_ui == null:
		return
	var target_name: String = _resolve_avatar_display_name(target_avatar)
	var title: String = "%s's inventory" % target_name
	var show_target_gun_slot: bool = source_inventory != null and source_inventory.has_method("get_gun_slot")
	_active_inspect_avatar_id = target_avatar.player_id
	_loot_inventory_ui.visible = true
	_set_loot_inventory_close_button_visible(true)
	_loot_inventory_ui.set_inventory_source(source_inventory)
	_loot_inventory_ui.set_inventory_context(false, "", title, true)
	_loot_inventory_ui.set_drag_permissions(false, false)
	_loot_inventory_ui.set_show_gun_slot(show_target_gun_slot)
	_loot_inventory_ui.set_gun_slot_interactive(false)


func _close_avatar_inspect_inventory_view() -> void:
	if _active_loot_npc_id > 0 or _active_loot_chest_id != -1:
		return
	_active_inspect_avatar_id = -1
	if _loot_inventory_ui == null:
		return
	_loot_inventory_ui.clear_inventory_source()
	_loot_inventory_ui.visible = false
	_set_loot_inventory_close_button_visible(false)


func _clear_inspect_target() -> void:
	_inspected_avatar = null
	_active_inspect_avatar_id = -1
	_close_avatar_inspect_inventory_view()


func _validate_inspected_avatar() -> void:
	if _inspected_avatar == null:
		return
	if is_instance_valid(_inspected_avatar):
		return
	_clear_inspect_target()


func _resolve_avatar_display_name(target_avatar: Avatar) -> String:
	if target_avatar == null or not is_instance_valid(target_avatar):
		return "Player"
	var resolved_name: String = target_avatar.display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Player_%d" % target_avatar.player_id
	return resolved_name


func _on_loot_inventory_close_button_pressed() -> void:
	if _active_loot_npc_id > 0 or _active_loot_chest_id != -1:
		close_loot_inventory()
		return
	_close_avatar_inspect_inventory_view()


func _set_loot_inventory_close_button_visible(is_visible: bool) -> void:
	if _loot_inventory_close_button == null:
		return
	_loot_inventory_close_button.visible = is_visible


func _restore_mouse_after_loot_close() -> void:
	if UIManager != null and _mouse_locked_before_loot_open:
		UIManager.capture_mouse()
	_mouse_locked_before_loot_open = false


func _on_gun_slot_drop_requested(from_slot: int) -> void:
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		return
	if not _bound_avatar.has_method("request_equip_gun_from_slot"):
		return
	_bound_avatar.call("request_equip_gun_from_slot", from_slot, from_slot)


func _on_gun_slot_unequip_requested() -> void:
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		return
	if not _bound_avatar.has_method("request_unequip_gun_to_inventory"):
		return
	_bound_avatar.call("request_unequip_gun_to_inventory")


func _initialize_item_inspect_popup_state() -> void:
	if _item_inspect_popup != null:
		_item_inspect_popup.visible = false


func _on_item_inspect_close_button_pressed() -> void:
	_close_item_inspect_popup()


func _close_item_inspect_popup() -> void:
	if _item_inspect_popup == null:
		return
	_item_inspect_popup.visible = false


func _on_item_inspect_requested(item_data_path: String) -> void:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return
	_open_item_inspect_popup(normalized_item_data_path)


func _open_item_inspect_popup(item_data_path: String) -> void:
	var item_data: Resource = _resolve_item_data(item_data_path)
	var fallback_name: String = item_data_path.get_file().get_basename()
	if fallback_name.is_empty():
		fallback_name = "Unknown Item"

	var title: String = fallback_name
	var description: String = "No description."
	var rarity_label: String = "Common"
	var icon: Texture2D = null
	var stats_lines: PackedStringArray = PackedStringArray()

	if item_data is ItemData:
		var base_item: ItemData = item_data as ItemData
		title = base_item.display_name.strip_edges()
		if title.is_empty():
			title = base_item.item_id.strip_edges()
		if title.is_empty():
			title = fallback_name

		description = base_item.description.strip_edges()
		if description.is_empty():
			description = "No description."

		rarity_label = _format_rarity_label(base_item.rarity)
		icon = base_item.icon

		if base_item is GunItemData:
			var gun_item: GunItemData = base_item as GunItemData
			stats_lines.append("Damage: %d" % gun_item.fire_damage)
			stats_lines.append("Fire Rate: %.2f/s" % gun_item.fire_rate_per_second)
			stats_lines.append("Range: %.1f" % gun_item.max_shoot_distance)
	elif item_data != null:
		var display_name_variant: Variant = item_data.get("display_name")
		var candidate_name: String = String(display_name_variant).strip_edges()
		if candidate_name.is_empty():
			var item_id_variant: Variant = item_data.get("item_id")
			candidate_name = String(item_id_variant).strip_edges()
		if not candidate_name.is_empty():
			title = candidate_name
		var icon_variant: Variant = item_data.get("icon")
		if icon_variant is Texture2D:
			icon = icon_variant as Texture2D

	if _item_inspect_title_label != null:
		_item_inspect_title_label.text = title
	if _item_inspect_description_label != null:
		_item_inspect_description_label.text = description
	if _item_inspect_rarity_label != null:
		_item_inspect_rarity_label.text = "Rarity: %s" % rarity_label
	if _item_inspect_icon != null:
		_item_inspect_icon.texture = icon
		_item_inspect_icon.visible = icon != null
	if _item_inspect_stats_section != null:
		_item_inspect_stats_section.visible = not stats_lines.is_empty()
	if _item_inspect_stats_label != null:
		_item_inspect_stats_label.text = "\n".join(stats_lines)
	if _item_inspect_popup != null:
		_item_inspect_popup.visible = true


func _resolve_item_data(item_data_path: String) -> Resource:
	var normalized_item_data_path: String = item_data_path.strip_edges()
	if normalized_item_data_path.is_empty():
		return null

	if _item_inspect_item_data_cache.has(normalized_item_data_path):
		var cached_variant: Variant = _item_inspect_item_data_cache.get(normalized_item_data_path)
		if cached_variant is Resource:
			return cached_variant as Resource
		return null

	var loaded_resource: Resource = load(normalized_item_data_path)
	if loaded_resource != null:
		_item_inspect_item_data_cache[normalized_item_data_path] = loaded_resource
		return loaded_resource
	_item_inspect_item_data_cache[normalized_item_data_path] = null
	return null


func _format_rarity_label(raw_rarity: String) -> String:
	var normalized: String = raw_rarity.strip_edges().to_lower()
	if normalized.is_empty():
		return "Common"
	var words: PackedStringArray = normalized.split("_", false)
	if words.is_empty():
		words = normalized.split(" ", false)
	if words.is_empty():
		return "Common"
	var formatted_words: PackedStringArray = PackedStringArray()
	for word in words:
		var cleaned_word: String = word.strip_edges()
		if cleaned_word.is_empty():
			continue
		formatted_words.append(cleaned_word.capitalize())
	if formatted_words.is_empty():
		return "Common"
	return " ".join(formatted_words)
