class_name NeoWorld
extends Node3D

const AVATAR_SCENE: PackedScene = preload("res://avatar/scenes/avatar.tscn")
const TEST_NPC_SCENE: PackedScene = preload("res://game_world/npc/test_npc.tscn")
@export var spawn_area_size: float = 20.0
@export var test_npc_spawn_count_on_server_start: int = 10
@export var test_npc_spawn_area_size: float = 20.0

var _next_test_npc_id: int = 1000000


func spawn_player_character(id: int, username: String = "") -> Avatar:
	# Server spawns a new player avatar and notifies clients.
	if not multiplayer.is_server():
		return null

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	player_avatar.player_id = id
	player_avatar.name = "Player_%s" % id
	player_avatar.display_name = username if not username.is_empty() else player_avatar.name
	player_avatar.set_multiplayer_authority(id)
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.position = Vector3(
		randf_range(-spawn_area_size, spawn_area_size),
		0.0,
		randf_range(-spawn_area_size, spawn_area_size)
	)

	_spawn_player_on_clients.rpc(id, player_avatar.global_position, player_avatar.name, player_avatar.display_name)
	return player_avatar


func sync_existing_players() -> void:
	# Server sends all existing avatars to newly connected clients.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			_spawn_player_on_clients.rpc(avatar.player_id, avatar.global_position, avatar.name, avatar.display_name)


func spawn_test_npcs(count: int = -1) -> void:
	if not multiplayer.is_server():
		return

	var spawn_count: int = count
	if spawn_count <= 0:
		spawn_count = maxi(test_npc_spawn_count_on_server_start, 0)
	for _i in range(spawn_count):
		spawn_test_npc(_next_test_npc_id)
		_next_test_npc_id += 1


func spawn_test_npc(npc_id: int) -> TestNpc:
	if not multiplayer.is_server():
		return null
	if %TestNpcs.has_node("TestNpc_%d" % npc_id):
		return null

	var npc: TestNpc = TEST_NPC_SCENE.instantiate() as TestNpc
	npc.name = "TestNpc_%d" % npc_id
	npc.npc_id = npc_id
	npc.display_name = "Duck_%d" % npc_id
	npc.set_multiplayer_authority(multiplayer.get_unique_id())
	%TestNpcs.add_child(npc)

	var spawn_position: Vector3 = Vector3(
		randf_range(-test_npc_spawn_area_size, test_npc_spawn_area_size),
		1.0,
		randf_range(-test_npc_spawn_area_size, test_npc_spawn_area_size)
	)
	npc.global_position = spawn_position
	npc.set_wander_center(Vector3.ZERO, test_npc_spawn_area_size)

	_spawn_test_npc_on_clients.rpc(npc_id, spawn_position, npc.name, npc.display_name)
	return npc


func sync_existing_test_npcs_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if peer_id <= 0:
		return

	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			_spawn_test_npc_on_clients.rpc_id(peer_id, npc.npc_id, npc.global_position, npc.name, npc.display_name)


func sync_customizations_to_peer(peer_id: int) -> void:
	# Server sends latest customization data to a newly connected client.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.last_customization_json != "":
			avatar._rpc_apply_customization.rpc_id(peer_id, avatar.last_customization_json)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_on_clients(id: int, position: Vector3, player_name: String, username: String) -> void:
	# Clients execute this to create a local representation.
	if multiplayer.is_server():
		return

	if %PlayerCharacters.has_node(player_name):
		return

	print("Spawning player avatar for ID: %s" % id)

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	player_avatar.player_id = id
	player_avatar.set_multiplayer_authority(id)
	player_avatar.name = player_name
	player_avatar.display_name = username if not username.is_empty() else player_name
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.global_position = position


@rpc("authority", "call_remote", "reliable")
func _spawn_test_npc_on_clients(npc_id: int, position: Vector3, npc_name: String, display_name: String) -> void:
	if multiplayer.is_server():
		return
	if %TestNpcs.has_node(npc_name):
		return

	var npc: TestNpc = TEST_NPC_SCENE.instantiate() as TestNpc
	npc.name = npc_name
	npc.npc_id = npc_id
	npc.display_name = display_name
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id > 0:
		npc.set_multiplayer_authority(sender_peer_id)
	%TestNpcs.add_child(npc)
	npc.global_position = position
	npc.set_wander_center(Vector3.ZERO, test_npc_spawn_area_size)


@rpc("authority", "call_remote", "reliable")
func _remove_player_on_clients(id: int) -> void:
	# Clients execute this to remove the player representation.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			return


@rpc("authority", "call_remote", "reliable")
func _remove_test_npc_on_clients(npc_id: int) -> void:
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			if npc.npc_id == npc_id:
				npc.queue_free()
				return


func remove_character_by_id(id: int) -> void:
	# Server removes authoritative node and notifies clients.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			break

	_remove_player_on_clients.rpc(id)


func remove_test_npc_by_id(npc_id: int) -> void:
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			if npc.npc_id == npc_id:
				npc.queue_free()
				break

	_remove_test_npc_on_clients.rpc(npc_id)


func remove_all_characters() -> void:
	# Remove all player avatars from the world.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			avatar.queue_free()
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			child.queue_free()
