class_name LeaveLobbyButton
extends Button

func _ready() -> void:
	hide()

	SessionManager.lobby_joined.connect(on_lobby_joined)
	SessionManager.lobby_left.connect(on_lobby_left)

	pressed.connect(_on_pressed)

func _on_pressed():
	SessionManager.leave_lobby()

func on_lobby_joined() -> void:
	show()

func on_lobby_left() -> void:
	hide()
