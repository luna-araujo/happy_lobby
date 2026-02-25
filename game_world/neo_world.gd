class_name NeoWorld
extends Node3D

const AVATAR_SCENE: PackedScene = preload("res://avatar/scenes/avatar.tscn")
@export var spawn_area_size: float = 20.0


func spawn_player_character(id: int) -> Avatar:
	# Server spawns a new player avatar and notifies clients.
	if not multiplayer.is_server():
		return null

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.player_id = id
	player_avatar.name = "Player_%s" % id
	player_avatar.position = Vector3(
		randf_range(-spawn_area_size, spawn_area_size),
		0.0,
		randf_range(-spawn_area_size, spawn_area_size)
	)
	player_avatar.set_multiplayer_authority(id)

	_spawn_player_on_clients.rpc(id, player_avatar.global_position, player_avatar.name)
	return player_avatar


func sync_existing_players() -> void:
	# Server sends all existing avatars to newly connected clients.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			_spawn_player_on_clients.rpc(avatar.player_id, avatar.global_position, avatar.name)


func sync_customizations_to_peer(peer_id: int) -> void:
	# Server sends latest customization data to a newly connected client.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.last_customization_json != "":
			avatar._rpc_apply_customization.rpc_id(peer_id, avatar.last_customization_json)


@rpc("authority", "call_remote", "unreliable")
func _spawn_player_on_clients(id: int, position: Vector3, player_name: String) -> void:
	# Clients execute this to create a local representation.
	if multiplayer.is_server():
		return

	if %PlayerCharacters.has_node(player_name):
		return

	print("Spawning player avatar for ID: %s" % id)

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.player_id = id
	player_avatar.set_multiplayer_authority(id)
	player_avatar.name = player_name
	player_avatar.global_position = position


@rpc("authority", "call_remote", "unreliable")
func _remove_player_on_clients(id: int) -> void:
	# Clients execute this to remove the player representation.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			return


func remove_character_by_id(id: int) -> void:
	# Server removes authoritative node and notifies clients.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			break

	_remove_player_on_clients.rpc(id)


func remove_all_characters() -> void:
	# Remove all player avatars from the world.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			avatar.queue_free()
