# Autoload -> SessionManager.gd
extends Node

const USING_STEAM: bool = true

var current_user: String = ""
var steam_id: int = 1
var player_character:Character = null

var game_world:GameWorld = null
var connected_players:Array[Dictionary] = []

var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()	

func _ready() -> void:
	game_world = get_tree().get_first_node_in_group("GameWorld") as GameWorld
	NetworkManager.steam_started.connect(_on_steam_started)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_steam_started() -> void:
	current_user = NetworkManager.steam_username
	steam_id = NetworkManager.steam_id



func join_lobby_by_ip(ip_address: String) -> void:
	var error:Error = peer.create_client(ip_address, 4242)
	if error != OK:
		print("Error connecting to lobby by IP: %s" % error)
		return
	multiplayer.multiplayer_peer = peer


func create_local_lobby() -> void:
	var error = peer.create_server(4242, 10)
	if error != OK:
		print("Created a local lobby: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	print("Created a local lobby, hosting on port 4242")
	
	# Server spawns itself as the first player (ID 1)
	var character = game_world.spawn_player_character(1)
	if character:
		connected_players.append({
			"id": 1,
			"username": get_user_os_username(),
			"steam_id": steam_id,
			"character": character
		})

func _on_connected_to_server() -> void:
	print("Connected to lobby by IP")

func _on_connection_failed() -> void:
	print("Failed to connect to lobby by IP")

func _on_peer_connected(id: int) -> void:
	print("Peer connected with ID: %s" % id)
	
	# Server spawns the player and handles RPC broadcasting
	if multiplayer.is_server():
		var character = game_world.spawn_player_character(id)
		connected_players.append({
			"id": id,
			"username": "Player_%d" % id,
			"steam_id": 0,
			"character": character
		})
		# Sync all existing players to the newly connected client
		game_world.sync_existing_players()
	else:
		# Client just registers itself in the connected_players array
		connected_players.append({
			"id": id,
			"username": "Player_%d" % id,
			"steam_id": 0,
			"character": null
		})


func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with ID: %s" % id)
	
	# Remove from connected players
	for i in range(connected_players.size()):
		if connected_players[i]["id"] == id:
			connected_players.remove_at(i)
			break
	
	# Server removes the authoritative node and broadcasts removal to clients
	if multiplayer.is_server():
		game_world.remove_character_by_id(id)

func get_user_os_username():
	var username = ""
	# Check for the 'USER' environment variable (common on Linux, macOS, Android)
	if OS.has_environment("USER"):
		username = OS.get_environment("USER")
	# Check for the 'USERNAME' environment variable (common on Windows)
	elif OS.has_environment("USERNAME"):
		username = OS.get_environment("USERNAME")
	else:
		# Fallback if neither environment variable is found
		username = "Player" 

	return username
