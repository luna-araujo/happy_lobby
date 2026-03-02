extends "res://interaction/interaction_area.gd"

@export var loot_prompt_text: String = "Loot"
@export var close_prompt_text: String = "Close"
@export var auto_close_extra_range: float = 0.4

var npc: TestNpc


func _ready() -> void:
	super._ready()
	npc = get_parent() as TestNpc
	execution_mode = ExecutionMode.LOCAL_ONLY
	if npc != null:
		interaction_distance = maxf(npc.loot_interaction_range, 0.1)


func _process(_delta: float) -> void:
	if npc == null:
		return
	if not _is_this_npc_open():
		return
	var local_peer_id: int = _resolve_local_peer_id()
	if local_peer_id <= 0:
		return
	var allowed_range: float = resolve_interaction_distance(npc.loot_interaction_range) + maxf(auto_close_extra_range, 0.0)
	if npc.can_be_looted_by(local_peer_id, allowed_range):
		return
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return
	player_ui.close_loot_inventory()


func can_interact(interactor: Node) -> bool:
	if not enabled:
		return false
	if npc == null:
		return false
	if interactor == null:
		return false
	if interactor.avatar == null:
		return false
	return npc.can_be_looted_by(
		interactor.avatar.player_id,
		resolve_interaction_distance(npc.loot_interaction_range)
	)


func can_interact_server(interactor_avatar: Avatar, interactor_peer_id: int) -> bool:
	if not enabled:
		return false
	if npc == null:
		return false
	if interactor_avatar == null:
		return false
	if interactor_peer_id <= 0:
		return false
	return npc.can_be_looted_by(
		interactor_peer_id,
		resolve_interaction_distance(npc.loot_interaction_range)
	)


func get_prompt_text(_interactor: Node) -> String:
	var corpse_name: String = _resolve_corpse_name()
	if _is_this_npc_open():
		return "%s %s" % [close_prompt_text.strip_edges(), corpse_name]
	return "%s %s" % [loot_prompt_text.strip_edges(), corpse_name]


func interact_local(_interactor: Node, _resolved_action_id: StringName) -> void:
	if npc == null:
		return
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return
	if npc.inventory == null:
		return
	if _is_this_npc_open():
		player_ui.close_loot_inventory()
		return
	player_ui.open_loot_inventory_for_npc(npc.npc_id, npc.inventory, _resolve_corpse_name())


func _resolve_player_ui() -> PlayerUi:
	if UIManager == null:
		return null
	if UIManager.player_ui == null:
		return null
	return UIManager.player_ui as PlayerUi


func _is_this_npc_open() -> bool:
	var player_ui: PlayerUi = _resolve_player_ui()
	if player_ui == null:
		return false
	return player_ui.get_active_loot_npc_id() == npc.npc_id


func _resolve_corpse_name() -> String:
	if npc == null:
		return "Corpse"
	var npc_name: String = npc.display_name.strip_edges()
	if npc_name.is_empty():
		npc_name = "Duck_%d" % npc.npc_id
	return "%s corpse" % npc_name


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
