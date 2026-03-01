extends Node

@export var player_ui_group: StringName = &"player_ui"

var player_ui: PlayerUi
var mouse_locked: bool = false


func _ready() -> void:
	_refresh_player_ui()
	_sync_mouse_lock_from_input()
	set_process_input(true)


func _process(_delta: float) -> void:
	if player_ui == null or not is_instance_valid(player_ui):
		_refresh_player_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_mouse_toggle"):
		toggle_mouse_lock()


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


func _refresh_player_ui() -> void:
	var found: Node = get_tree().get_first_node_in_group(String(player_ui_group))
	player_ui = found as PlayerUi


func _sync_mouse_lock_from_input() -> void:
	mouse_locked = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
