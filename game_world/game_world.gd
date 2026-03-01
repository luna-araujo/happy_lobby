class_name GameWorld
extends Node2D

func spawn_player_character(id: int) -> Character:
	# Server spawns a new player character and notifies clients
	if not multiplayer.is_server():
		return null
	
	var character_scene: PackedScene = preload("res://game_world/char/char.tscn")
	var player_character: Character = character_scene.instantiate() as Character
	%PlayerCharacters.add_child(player_character)
	player_character.player_id = id
	player_character.name = "Player_%s" % id
	player_character.position = Vector2(randf() * 400, randf() * 400)
	player_character.set_multiplayer_authority(id)

	# Notify all clients to spawn their representation
	_spawn_player_on_clients.rpc(id, player_character.global_position, player_character.name)
	
	return player_character


func sync_existing_players() -> void:
	# Server sends all existing players to newly connected clients
	if not multiplayer.is_server():
		return
	
	for character in %PlayerCharacters.get_children():
		if character is Character:
			_spawn_player_on_clients.rpc(character.player_id, character.global_position, character.name)

func sync_customizations_to_peer(peer_id: int) -> void:
	# Server sends latest customization data to a newly connected client
	if not multiplayer.is_server():
		return
	for character in %PlayerCharacters.get_children():
		if character is Character and character.last_customization_json != "":
			character._rpc_apply_customization.rpc_id(peer_id, character.last_customization_json)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_on_clients(id: int, position: Vector2, player_name: String) -> void:
	# Clients execute this to create a local representation
	if multiplayer.is_server():
		return
	
	# Avoid duplicates
	if %PlayerCharacters.has_node(player_name):
		return
	
	print("Spawning player character for ID: %s" % id)

	var character_scene: PackedScene = preload("res://game_world/char/char.tscn")
	var player_character: Character = character_scene.instantiate() as Character
	%PlayerCharacters.add_child(player_character)
	player_character.player_id = id
	player_character.name = player_name
	player_character.global_position = position


@rpc("authority", "call_remote", "reliable")
func _remove_player_on_clients(id: int) -> void:
	# Clients execute this to remove the player representation
	for character in %PlayerCharacters.get_children():
		if character is Character and character.player_id == id:
			character.queue_free()
			return


func remove_character_by_id(id: int) -> void:
	# Server removes authoritative node and notifies clients
	for character in %PlayerCharacters.get_children():
		if character is Character and character.player_id == id:
			character.queue_free()
			break
	
	# Notify all clients to remove their representation
	_remove_player_on_clients.rpc(id)

func remove_all_characters() -> void:
	# Remove all player characters from the game world
	for character in %PlayerCharacters.get_children():
		if character is Character:
			character.queue_free()
