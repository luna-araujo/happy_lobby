extends Node

@export var player_ui_group: StringName = &"player_ui"
@export var main_menu_path: NodePath = NodePath("/root/Main/MainMenu")

var player_ui: PlayerUi
var main_menu: Control
var mouse_locked: bool = false
var _mouse_locked_before_main_menu_open: bool = false


func _ready() -> void:
	_refresh_player_ui()
	_refresh_main_menu()
	_sync_mouse_lock_from_input()
	_connect_session_signals()
	set_process_input(true)


func _process(_delta: float) -> void:
	if player_ui == null or not is_instance_valid(player_ui):
		_refresh_player_ui()
	if main_menu == null or not is_instance_valid(main_menu):
		_refresh_main_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_mouse_toggle"):
		toggle_mouse_lock()
	if event.is_action_pressed("ui_main_menu_toggle"):
		toggle_main_menu()


func set_mouse_locked(locked: bool) -> void:
	mouse_locked = locked
	if mouse_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func toggle_mouse_lock() -> void:
	set_mouse_locked(not mouse_locked)


func capture_mouse() -> void:
	set_mouse_locked(true)


func release_mouse() -> void:
	set_mouse_locked(false)


func is_main_menu_visible() -> bool:
	if main_menu == null or not is_instance_valid(main_menu):
		return false
	return main_menu.visible


func set_main_menu_visible(visible: bool) -> void:
	if main_menu == null or not is_instance_valid(main_menu):
		_refresh_main_menu()
	if main_menu == null or not is_instance_valid(main_menu):
		return
	if main_menu.visible == visible:
		return

	if visible:
		_mouse_locked_before_main_menu_open = mouse_locked
		main_menu.visible = true
		release_mouse()
		return

	main_menu.visible = false
	if _mouse_locked_before_main_menu_open:
		capture_mouse()
	_mouse_locked_before_main_menu_open = false


func show_main_menu() -> void:
	set_main_menu_visible(true)


func hide_main_menu() -> void:
	set_main_menu_visible(false)


func toggle_main_menu() -> void:
	set_main_menu_visible(not is_main_menu_visible())


func _refresh_player_ui() -> void:
	var found: Node = get_tree().get_first_node_in_group(String(player_ui_group))
	player_ui = found as PlayerUi


func _refresh_main_menu() -> void:
	main_menu = get_node_or_null(main_menu_path) as Control


func _sync_mouse_lock_from_input() -> void:
	mouse_locked = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _connect_session_signals() -> void:
	if SessionManager == null:
		return
	if not SessionManager.has_signal("lobby_joined"):
		return
	if not SessionManager.has_signal("lobby_left"):
		return
	if not SessionManager.lobby_joined.is_connected(_on_lobby_joined):
		SessionManager.lobby_joined.connect(_on_lobby_joined)
	if not SessionManager.lobby_left.is_connected(_on_lobby_left):
		SessionManager.lobby_left.connect(_on_lobby_left)


func _on_lobby_joined() -> void:
	hide_main_menu()


func _on_lobby_left() -> void:
	show_main_menu()
