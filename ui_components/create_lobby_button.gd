class_name CreateLobbyButton
extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)
	SessionManager.lobby_joined.connect(on_lobby_joined)
	SessionManager.lobby_left.connect(on_lobby_left)

	if SessionManager.USING_STEAM == false:
		text = "Host Local Lobby"
		tooltip_text = "Host a local lobby (Steam not enabled)"


func _on_pressed():
	if SessionManager.USING_STEAM == false:
		SessionManager.create_local_lobby()
		hide()
		return

	
	
	NetworkManager.lobby.create_lobby()


func on_lobby_joined() -> void:
	hide()


func on_lobby_left() -> void:
	show()
