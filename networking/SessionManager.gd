# Autoload -> SessionManager.gd
extends Node

const USING_STEAM: bool = false # Set to false to disable Steam integration and use local LAN play instead
const STEAM_VIRTUAL_PORT: int = 0

signal lobby_joined
signal lobby_left

var current_user: String = ""
var steam_id: int = 1
var player_character: Avatar = null

var game_world: NeoWorld = null
var connected_players:Array[Dictionary] = []
var host_peer_id: int = 1

var peer: MultiplayerPeer = null
var is_steam_peer: bool = false

func _ready() -> void:
	game_world = _find_neo_world()
	if game_world == null:
		push_error("NeoWorld node not found. SessionManager cannot spawn players.")
	NetworkManager.steam_started.connect(_on_steam_started)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_steam_started() -> void:
	current_user = NetworkManager.steam_username
	steam_id = NetworkManager.steam_id


func join_lobby_by_ip(ip_address: String) -> bool:
	var enet_peer := ENetMultiplayerPeer.new()
	var error:Error = enet_peer.create_client(ip_address, 4242)
	if error != OK:
		push_error("Error connecting to lobby by IP: %s" % error)
		return false
	_set_peer(enet_peer, false)
	host_peer_id = 1
	return true


func create_local_lobby() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(4242, 10)
	if error != OK:
		push_error("Error creating a local lobby: %s" % error)
		return

	_set_peer(enet_peer, false)
	host_peer_id = multiplayer.get_unique_id()
	print("Created a local lobby, hosting on port 4242")
	lobby_joined.emit()
	
	# Server spawns itself using the server's unique ID
	var local_id := multiplayer.get_unique_id()
	if game_world == null:
		return
	var character := game_world.spawn_player_character(local_id)
	if character:
		connected_players.append({
			"id": local_id,
			"username": get_user_os_username(),
			"steam_id": steam_id,
			"character": character
		})

func leave_lobby() -> void:
	if NetworkManager.using_steam and NetworkManager.lobby.lobby_id != 0:
		Steam.leaveLobby(NetworkManager.lobby.lobby_id)
		NetworkManager.lobby.lobby_id = 0
		NetworkManager.lobby.lobby_members.clear()

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	connected_players.clear()
	lobby_left.emit()
	if game_world:
		game_world.remove_all_characters()
	print("Left the lobby")

func _on_connected_to_server() -> void:
	print("Connected to lobby by IP")
	lobby_joined.emit()

func _on_connection_failed() -> void:
	print("Failed to connect to lobby by IP")
	lobby_left.emit()

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	lobby_left.emit()

func _on_peer_connected(id: int) -> void:
	print("Peer connected with ID: %s" % id)
	
	# Server spawns the player and handles RPC broadcasting
	if multiplayer.is_server():
		if game_world == null:
			return
		var username := "Player_%d" % id
		var player_steam_id := 0
		if is_steam_peer:
			player_steam_id = id
			username = Steam.getFriendPersonaName(id)
		var character := game_world.spawn_player_character(id)
		connected_players.append({
			"id": id,
			"username": username,
			"steam_id": player_steam_id,
			"character": character
		})
		# Sync all existing players to the newly connected client
		game_world.sync_existing_players()
		game_world.call_deferred("sync_customizations_to_peer", id)
	else:
		var username := "Player_%d" % id
		var player_steam_id := 0
		if is_steam_peer:
			player_steam_id = id
			username = Steam.getFriendPersonaName(id)
		# Client just registers itself in the connected_players array
		connected_players.append({
			"id": id,
			"username": username,
			"steam_id": player_steam_id,
			"character": null
		})


func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with ID: %s" % id)
	if id == multiplayer.get_unique_id() || id == host_peer_id:
		if game_world:
			game_world.remove_all_characters()
		lobby_left.emit()
		connected_players.clear()
		return

	
	# Remove from connected players
	for i in range(connected_players.size()):
		if connected_players[i]["id"] == id:
			connected_players.remove_at(i)
			break
	
	# Server removes the authoritative node and broadcasts removal to clients
	if multiplayer.is_server() and game_world:
		game_world.remove_character_by_id(id)

func create_steam_host(lobby_id: int) -> void:
	var steam_peer := _create_steam_peer()
	if steam_peer == null:
		return

	var error: Error
	if steam_peer.has_method("host_with_lobby"):
		error = steam_peer.host_with_lobby(lobby_id)
	else:
		error = steam_peer.create_host(STEAM_VIRTUAL_PORT)
	if error != OK:
		push_error("Error creating Steam P2P host: %s" % error)
		return

	_set_peer(steam_peer, true)
	host_peer_id = multiplayer.get_unique_id()
	print("Created a Steam P2P lobby host")
	lobby_joined.emit()

	# Server spawns itself using the server's unique ID
	var local_id := multiplayer.get_unique_id()
	if game_world == null:
		return
	var character := game_world.spawn_player_character(local_id)
	if character:
		connected_players.append({
			"id": local_id,
			"username": current_user,
			"steam_id": steam_id,
			"character": character
		})

func join_steam_lobby(lobby_id: int) -> bool:
	var steam_peer := _create_steam_peer()
	if steam_peer == null:
		return false

	var error: Error
	if steam_peer.has_method("connect_to_lobby"):
		var owner_id := Steam.getLobbyOwner(lobby_id)
		if owner_id > 0:
			host_peer_id = owner_id
		error = steam_peer.connect_to_lobby(lobby_id)
	else:
		var owner_id := Steam.getLobbyOwner(lobby_id)
		if owner_id == 0:
			push_error("Could not determine lobby owner for Steam lobby: %s" % lobby_id)
			return false
		host_peer_id = owner_id
		error = steam_peer.create_client(owner_id, STEAM_VIRTUAL_PORT)
	if error != OK:
		push_error("Error connecting to Steam P2P host: %s" % error)
		return false

	_set_peer(steam_peer, true)
	return true

func _create_steam_peer() -> MultiplayerPeer:
	if !ClassDB.class_exists("SteamMultiplayerPeer"):
		push_error("SteamMultiplayerPeer class not found. Ensure the GodotSteam MultiplayerPeer build is being used.")
		return null
	return ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer

func _set_peer(new_peer: MultiplayerPeer, using_steam_peer: bool) -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = new_peer
	peer = new_peer
	is_steam_peer = using_steam_peer

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


func _find_neo_world() -> NeoWorld:
	var world := get_tree().get_first_node_in_group("NeoWorld") as NeoWorld
	if world:
		return world

	world = get_tree().root.find_child("NeoWorld", true, false) as NeoWorld
	return world
