class_name LobbyListView
extends Control

@export var player_entry_scene: PackedScene
var list_Container: VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Steam.lobby_joined.connect(_on_lobby_joined)
	list_Container = $VBoxContainer/PlayerList


func _on_lobby_joined( lobby: int, permissions: int, locked: bool, response: int ) -> void:
	print("LobbyListView detected joined lobby: %s" % lobby)

	# Clear any previous entries
	var children = list_Container.get_children()
	for child in children:
		child.queue_free()
	
	# Get the current members of the lobby
	var num_members: int = Steam.getNumLobbyMembers(lobby)
	for i in range(num_members):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby, i)
		print("Lobby Member %s: %s" % [i, member_steam_id])
		var player_entry: PlayerEntry = PlayerEntry.new_entry(member_steam_id)
		player_entry.setup(member_steam_id)
		list_Container.add_child(player_entry)
