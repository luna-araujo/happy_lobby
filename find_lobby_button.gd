extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed():
	NetworkManager.lobby.get_lobby_list()
	
	if not Steam.lobby_match_list.is_connected(_on_lobby_match_list):
		Steam.lobby_match_list.connect(_on_lobby_match_list)


func _on_lobby_match_list(these_lobbies: Array) -> void:
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
		lobby_button.pressed.connect(NetworkManager.lobby.join_lobby.bind(this_lobby))

		# Add the new lobby to the list
		$"../../Lobbies/Scroll/List".add_child(lobby_button)
