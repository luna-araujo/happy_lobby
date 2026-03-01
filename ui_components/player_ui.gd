class_name PlayerUi
extends CanvasLayer

@export var rebind_interval_seconds: float = 0.25
@export var neo_world_group_name: StringName = &"NeoWorld"

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Panel
@onready var _name_label: Label = $Root/Panel/Margin/VBox/PlayerName
@onready var _hp_bar: ProgressBar = $Root/Panel/Margin/VBox/HpBar
@onready var _hp_label: Label = $Root/Panel/Margin/VBox/HpLabel
@onready var _status_value_label: Label = $Root/Panel/Margin/VBox/StatusValue
@onready var _status_details_label: Label = $Root/Panel/Margin/VBox/StatusDetails
@onready var _inventory_ui: Node = $Root/Panel/Margin/VBox/InventoryUi

var _bound_avatar: Avatar
var _bound_combat: CharacterCombat
var _bound_inventory: Inventory
var _player_characters_root: Node
var _rebind_timer: float = 0.0


func _ready() -> void:
	layer = 90
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
		if not _bound_combat.hp_changed.is_connected(_on_hp_changed):
			_bound_combat.hp_changed.connect(_on_hp_changed)
		if not _bound_combat.state_changed.is_connected(_on_state_changed):
			_bound_combat.state_changed.connect(_on_state_changed)
	if _inventory_ui != null and _inventory_ui.has_method("set_inventory_source"):
		_inventory_ui.call("set_inventory_source", _bound_inventory)

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
		if _bound_combat.hp_changed.is_connected(_on_hp_changed):
			_bound_combat.hp_changed.disconnect(_on_hp_changed)
		if _bound_combat.state_changed.is_connected(_on_state_changed):
			_bound_combat.state_changed.disconnect(_on_state_changed)

	if _bound_avatar != null and is_instance_valid(_bound_avatar):
		if _bound_avatar.tree_exiting.is_connected(_on_bound_avatar_tree_exiting):
			_bound_avatar.tree_exiting.disconnect(_on_bound_avatar_tree_exiting)

	_bound_avatar = null
	_bound_combat = null
	_bound_inventory = null
	if _inventory_ui != null and _inventory_ui.has_method("clear_inventory_source"):
		_inventory_ui.call("clear_inventory_source")


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
	var resolved_name: String = _bound_avatar.display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Player_%d" % _bound_avatar.player_id
	_name_label.text = resolved_name


func _refresh_health() -> void:
	if _hp_bar == null or _hp_label == null:
		return
	if _bound_combat == null or not is_instance_valid(_bound_combat):
		_hp_bar.max_value = 1
		_hp_bar.value = 0
		_hp_label.text = "HP: --/--"
		return
	var safe_max: int = maxi(_bound_combat.max_hp, 1)
	var safe_hp: int = clampi(_bound_combat.hp, 0, safe_max)
	_hp_bar.max_value = safe_max
	_hp_bar.value = safe_hp
	_hp_label.text = "HP: %d/%d" % [safe_hp, safe_max]


func _refresh_status() -> void:
	if _status_value_label == null or _status_details_label == null:
		return
	if _bound_combat == null or not is_instance_valid(_bound_combat):
		_status_value_label.text = "Status: --"
		_status_details_label.text = "No combat data."
		return

	var state_name: String = _combat_state_name(_bound_combat.state)
	_status_value_label.text = "Status: %s" % state_name
	_status_details_label.text = "Can Act: %s\nIs Dead: %s\nParry CD: %.2fs" % [
		str(_bound_combat.can_act()),
		str(_bound_combat.is_dead()),
		_bound_combat.get_parry_cooldown_remaining()
	]


func _combat_state_name(state_value: int) -> String:
	match state_value:
		CharacterCombat.CombatState.READY:
			return "READY"
		CharacterCombat.CombatState.QUICK_MELEE:
			return "QUICK_MELEE"
		CharacterCombat.CombatState.HEAVY_MELEE:
			return "HEAVY_MELEE"
		CharacterCombat.CombatState.PARRYING:
			return "PARRYING"
		CharacterCombat.CombatState.STUNNED:
			return "STUNNED"
		CharacterCombat.CombatState.DEAD:
			return "DEAD"
	return "UNKNOWN(%d)" % state_value


func _set_panel_visible(is_visible: bool) -> void:
	if _root != null:
		_root.visible = is_visible
	if _panel != null:
		_panel.visible = is_visible


func _on_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_refresh_health()


func _on_state_changed(_previous_state: int, _new_state: int) -> void:
	_refresh_status()


func _on_bound_avatar_tree_exiting() -> void:
	clear_player_avatar()
