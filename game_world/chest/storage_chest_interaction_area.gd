extends "res://interaction/interaction_area.gd"

@export var open_prompt_text: String = "Open"
@export var close_prompt_text: String = "Close"
@export var auto_close_extra_range: float = 0.4

var chest: StorageChest


func _ready() -> void:
	super._ready()
	chest = get_parent() as StorageChest
	execution_mode = ExecutionMode.LOCAL_ONLY
	if chest != null:
		interaction_distance = maxf(chest.interaction_range, 0.1)


func _process(_delta: float) -> void:
	if chest == null:
		return
	if not _is_this_chest_open():
		return
	var local_peer_id: int = _resolve_local_peer_id()
	if local_peer_id <= 0:
		return
	var allowed_range: float = resolve_interaction_distance(chest.interaction_range) + maxf(auto_close_extra_range, 0.0)
	if chest.can_be_accessed_by(local_peer_id, allowed_range):
		return
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return
	player_ui.close_loot_inventory()


func can_interact(interactor: Node) -> bool:
	if not enabled:
		return false
	if chest == null:
		return false
	if interactor == null:
		return false
	if interactor.avatar == null:
		return false
	return chest.can_be_accessed_by(
		interactor.avatar.player_id,
		resolve_interaction_distance(chest.interaction_range)
	)


func can_interact_server(interactor_avatar: Avatar, interactor_peer_id: int) -> bool:
	if not enabled:
		return false
	if chest == null:
		return false
	if interactor_avatar == null:
		return false
	if interactor_peer_id <= 0:
		return false
	return chest.can_be_accessed_by(
		interactor_peer_id,
		resolve_interaction_distance(chest.interaction_range)
	)


func get_prompt_text(_interactor: Node) -> String:
	var chest_name: String = _resolve_chest_name()
	if _is_this_chest_open():
		return "%s %s" % [close_prompt_text.strip_edges(), chest_name]
	return "%s %s" % [open_prompt_text.strip_edges(), chest_name]


func interact_local(_interactor: Node, _resolved_action_id: StringName) -> void:
	if chest == null:
		return
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return
	if chest.inventory == null:
		return
	if _is_this_chest_open():
		player_ui.close_loot_inventory()
		return
	player_ui.open_loot_inventory_for_chest(chest.chest_id, chest.inventory, _resolve_chest_name())


func _resolve_player_ui() -> PlayerUi:
	if UIManager == null:
		return null
	if UIManager.player_ui == null:
		return null
	return UIManager.player_ui as PlayerUi


func _is_this_chest_open() -> bool:
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return false
	return player_ui.get_active_loot_chest_id() == chest.chest_id


func _resolve_chest_name() -> String:
	if chest == null:
		return "Chest"
	var chest_name: String = chest.display_name.strip_edges()
	if chest_name.is_empty():
		return "Chest"
	return chest_name


func _resolve_local_peer_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 1
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return 1
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return 1
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return 1
	return local_peer_id
