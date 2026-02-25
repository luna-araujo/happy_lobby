class_name AvatarEditor
extends Control

@onready var avatar: Avatar = %Avatar
@onready var skin_color_picker: ColorPickerButton = %SkinColorPicker
@onready var avatar_color_picker: ColorPickerButton = %AvatarColorPicker
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton


func _ready() -> void:
	_disable_in_menu_runtime_controls()

	if avatar:
		avatar.customized.connect(update_options)

	if save_button:
		save_button.pressed.connect(func():
			Avatar.store_save(avatar)
		)

	if load_button:
		load_button.pressed.connect(func():
			Avatar.load_save(avatar)
			update_options()
		)

	if skin_color_picker:
		skin_color_picker.color_changed.connect(_on_skin_color_changed)
	if avatar_color_picker:
		avatar_color_picker.color_changed.connect(_on_avatar_color_changed)

	update_options()


func _disable_in_menu_runtime_controls() -> void:
	if avatar and is_instance_valid(avatar.movement_body):
		avatar.movement_body.set_physics_process(false)
		avatar.movement_body.set_process_input(false)
		avatar.movement_body.velocity = Vector3.ZERO

	if avatar and is_instance_valid(avatar.third_person_camera):
		avatar.third_person_camera.capture_mouse_on_ready = false
		avatar.third_person_camera.set_process(false)
		avatar.third_person_camera.set_process_input(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func update_options() -> void:
	if not avatar:
		return

	_set_picker_color_no_signal(skin_color_picker, avatar.get_color("skin_color"))
	_set_picker_color_no_signal(avatar_color_picker, avatar.get_color("avatar_color"))


func _set_picker_color_no_signal(picker: ColorPickerButton, value: Color) -> void:
	if not picker:
		return
	picker.set_block_signals(true)
	picker.color = value
	picker.set_block_signals(false)


func _on_skin_color_changed(new_color: Color) -> void:
	if avatar:
		avatar.set_color("skin_color", new_color)


func _on_avatar_color_changed(new_color: Color) -> void:
	if avatar:
		avatar.set_color("avatar_color", new_color)
