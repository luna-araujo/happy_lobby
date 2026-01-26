class_name FindLobbyButton
extends Button

func _ready() -> void:
	if NetworkManager.using_steam == false:
		disabled = true
		hide()
		return

	pressed.connect(_on_pressed)

func _on_pressed():
	NetworkManager.lobby.get_lobby_list()
	
	LobbyFinderWindow.create_window(get_tree())


