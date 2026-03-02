@tool
extends EditorPlugin

const STEAM_ENV_NAME: String = "HAPPY_LOBBY_STEAM"
const STEAM_ICON_PATH: String = "res://addons/steam_play_button/icons/steam.svg"

var steam_play_button: Button = null
var remaining_place_attempts: int = 0


func _enter_tree() -> void:
	steam_play_button = Button.new()
	steam_play_button.focus_mode = Control.FOCUS_NONE
	steam_play_button.tooltip_text = "Play Main Scene with Steam"
	steam_play_button.flat = true
	steam_play_button.icon = load(STEAM_ICON_PATH) as Texture2D
	steam_play_button.custom_minimum_size = Vector2.ZERO
	steam_play_button.pressed.connect(_on_steam_play_pressed)

	# Add first via plugin API so enable/disable lifecycle remains editor-friendly.
	add_control_to_container(CONTAINER_TOOLBAR, steam_play_button)

	# Then try to place it right after Godot's Main Play button.
	remaining_place_attempts = 20
	set_process(true)


func _process(_delta: float) -> void:
	if steam_play_button == null:
		set_process(false)
		return

	if remaining_place_attempts <= 0:
		set_process(false)
		return

	if _try_place_next_to_play_button():
		set_process(false)
		return

	remaining_place_attempts -= 1


func _exit_tree() -> void:
	set_process(false)
	remaining_place_attempts = 0

	if steam_play_button == null:
		return

	# If still in standard plugin container, cleanly remove it.
	if steam_play_button.get_parent() != null:
		remove_control_from_container(CONTAINER_TOOLBAR, steam_play_button)
		if steam_play_button.get_parent() != null:
			steam_play_button.get_parent().remove_child(steam_play_button)

	steam_play_button.queue_free()
	steam_play_button = null


func _on_steam_play_pressed() -> void:
	var had_previous_value: bool = OS.has_environment(STEAM_ENV_NAME)
	var previous_value: String = OS.get_environment(STEAM_ENV_NAME)
	OS.set_environment(STEAM_ENV_NAME, "1")

	var editor_interface: EditorInterface = get_editor_interface()
	if editor_interface == null:
		_restore_env_value(had_previous_value, previous_value)
		push_warning("Steam Play Button: Could not access editor interface.")
		return

	var is_playing: bool = false
	if editor_interface.has_method("is_playing_scene"):
		is_playing = bool(editor_interface.call("is_playing_scene"))
	if is_playing and editor_interface.has_method("stop_playing_scene"):
		editor_interface.call("stop_playing_scene")

	call_deferred("_launch_main_scene_with_restore", had_previous_value, previous_value)


func _launch_main_scene_with_restore(had_previous_value: bool, previous_value: String) -> void:
	var editor_interface: EditorInterface = get_editor_interface()
	var launch_ok: bool = false

	if editor_interface != null and editor_interface.has_method("play_main_scene"):
		var launch_result: Variant = editor_interface.call("play_main_scene")
		if launch_result is bool:
			launch_ok = launch_result
		else:
			launch_ok = true

	_restore_env_value(had_previous_value, previous_value)

	if not launch_ok:
		push_warning("Steam Play Button: Failed to launch main scene.")


func _restore_env_value(had_previous_value: bool, previous_value: String) -> void:
	if had_previous_value:
		OS.set_environment(STEAM_ENV_NAME, previous_value)
		return

	if OS.has_method("unset_environment"):
		OS.call("unset_environment", STEAM_ENV_NAME)
	else:
		OS.set_environment(STEAM_ENV_NAME, "")


func _try_place_next_to_play_button() -> bool:
	if steam_play_button == null:
		return false

	var play_icon: Texture2D = _find_editor_icon([
		"MainPlay",
		"PlayMainScene",
		"Play",
		"PlayScene"
	])
	if play_icon == null:
		return false

	var base_control: Control = get_editor_interface().get_base_control()
	var play_button: Button = _find_button_with_icon(base_control, play_icon)
	if play_button == null:
		return false

	var parent_node: Node = play_button.get_parent()
	if parent_node == null:
		return false

	if steam_play_button.has_method("set_icon_max_width") and play_button.icon != null:
		steam_play_button.call("set_icon_max_width", play_button.icon.get_width())

	if steam_play_button.get_parent() != parent_node:
		if steam_play_button.get_parent() != null:
			steam_play_button.get_parent().remove_child(steam_play_button)
		parent_node.add_child(steam_play_button)

	var play_index: int = play_button.get_index()
	parent_node.move_child(steam_play_button, play_index + 1)
	return true


func _find_button_with_icon(node: Node, target_icon: Texture2D) -> Button:
	if node is Button:
		var button: Button = node as Button
		if button.icon == target_icon:
			return button

	for child in node.get_children():
		var found: Button = _find_button_with_icon(child, target_icon)
		if found != null:
			return found

	return null


func _find_editor_icon(candidates: Array[String]) -> Texture2D:
	var editor_base: Control = get_editor_interface().get_base_control()
	for icon_name in candidates:
		if editor_base.has_theme_icon(icon_name, "EditorIcons"):
			return editor_base.get_theme_icon(icon_name, "EditorIcons")
	return null
