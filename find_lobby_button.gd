extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed():
	NetworkManager.lobby.get_lobby_list()
	
	LobbyFinderWindow.create_window(get_tree())


