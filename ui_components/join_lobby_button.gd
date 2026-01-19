class_name JoinLobbyButton
extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if NetworkManager.using_steam:
		hide()
		return

	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	SessionManager.join_lobby_by_ip("localhost")
	hide()
	# var new_popup = PopupPanel.new()
	# new_popup.borderless = false;
	# new_popup.title = "Join Lobby"
	# new_popup.transient = true;
	# var lobby_code_input = LineEdit.new()
	# lobby_code_input.placeholder_text = "Enter host ip address"
	# lobby_code_input.text_submitted.connect(func(ip: String) -> void:
	# 	NetworkManager.lobby.join_lobby_by_ip(ip)
	# 	new_popup.hide()
	# )
	# new_popup.add_child(lobby_code_input)
	# get_tree().root.add_child(new_popup)
	# new_popup.popup_centered(Vector2i(300, 60))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
