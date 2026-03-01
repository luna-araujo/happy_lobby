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
@onready var _interaction_prompt_panel: PanelContainer = $Root/InteractionPrompt
@onready var _interaction_prompt_label: Label = $Root/InteractionPrompt/Margin/PromptLabel

var _bound_avatar: Avatar
var _bound_combat: CharacterCombat
var _bound_inventory: Inventory
var _player_characters_root: Node
var _rebind_timer: float = 0.0
var _status_labels: Dictionary = {}
var _active_loot_npc_id: int = -1
var _interaction_prompt_target_visible: bool = false
var _interaction_prompt_tween: Tween


func _ready() -> void:
	layer = 90
	_configure_inventory_ui()
	_initialize_interaction_prompt_state()
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
		_inventory_ui.set_inventory_source(_bound_inventory)
		_inventory_ui.set_inventory_context(true, _resolve_display_name(), "", false)
		_inventory_ui.set_drag_permissions(true, true)

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
	if _inventory_ui != null:
		_inventory_ui.clear_inventory_source()
	close_loot_inventory()
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
	_active_loot_npc_id = npc_id
	_loot_inventory_ui.visible = true
	_loot_inventory_ui.set_inventory_source(source_inventory)
	_loot_inventory_ui.set_inventory_context(false, "", container_name, false)
	_loot_inventory_ui.set_drag_permissions(true, false)


func close_loot_inventory() -> void:
	_active_loot_npc_id = -1
	if _loot_inventory_ui == null:
		return
	_loot_inventory_ui.clear_inventory_source()
	_loot_inventory_ui.visible = false


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
	if _loot_inventory_ui != null:
		_loot_inventory_ui.visible = false
		_loot_inventory_ui.set_drag_permissions(true, false)


func _on_inventory_external_drop_requested(source_ui: InventoryUi, from_slot: int, target_ui: InventoryUi, to_slot: int) -> void:
	if _bound_avatar == null or not is_instance_valid(_bound_avatar):
		return
	if _active_loot_npc_id <= 0:
		return
	if source_ui != _loot_inventory_ui:
		return
	if target_ui != _inventory_ui:
		return
	if not _bound_avatar.has_method("request_loot_transfer"):
		return
	_bound_avatar.call("request_loot_transfer", _active_loot_npc_id, from_slot, to_slot)
