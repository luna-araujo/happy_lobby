class_name JoinLobbyButton
extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if NetworkManager.using_steam:
		hide()
		return


	SessionManager.lobby_joined.connect(on_lobby_joined)
	SessionManager.lobby_left.connect(on_lobby_left)
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	SessionManager.join_lobby_by_ip("localhost")
	hide()

func on_lobby_joined() -> void:
	hide()

func on_lobby_left() -> void:
	show()