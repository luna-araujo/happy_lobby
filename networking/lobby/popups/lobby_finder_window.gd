class_name LobbyFinderWindow
extends Window

var refresh: Callable

func _ready() -> void:
	Steam.lobby_joined.connect(_on_steam_lobby_joined)

	close_requested.connect(_on_close_requested)

	refresh = NetworkManager.lobby.get_lobby_list
	refresh.call()
	%RefreshButton.pressed.connect(refresh)
	
	if not Steam.lobby_match_list.is_connected(_on_lobby_match_list):
		Steam.lobby_match_list.connect(_on_lobby_match_list)


func _on_lobby_match_list(these_lobbies: Array) -> void:
	var children: Array[Node] = %List.get_children()
	for child in children:
		child.queue_free()

	for this_lobby in these_lobbies:
		# Pull lobby data from Steam, these are specific to our example
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")

		# Get the current number of members
		var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)

		# Create a button for the lobby
		var lobby_button: Button = Button.new()
		lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % this_lobby)
		lobby_button.pressed.connect(NetworkManager.lobby.join_steam_lobby.bind(this_lobby))

		# Add the new lobby to the list
		%"List".add_child(lobby_button)


func _on_steam_lobby_joined( lobby: int, permissions: int, locked: bool, response: int ) -> void:
	close()


func _on_close_requested():
	close()


func close():
	queue_free()


static func create_window(scene_tree: SceneTree) -> LobbyFinderWindow:
	var new_window: LobbyFinderWindow = ResourceLoader.load("res://networking/lobby/popups/lobby_finder_window.tscn").instantiate() as LobbyFinderWindow
	scene_tree.root.add_child(new_window)
	return new_window
