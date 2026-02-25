class_name Avatar
extends Node3D

signal customized

var _player_id: int = 1
var player_id: int:
	get:
		return _player_id
	set(id):
		_player_id = id
		if is_instance_valid(movement_body):
			movement_body.set_multiplayer_authority(id)
		var player_input := get_node_or_null("PlayerInput")
		if player_input:
			player_input.set_multiplayer_authority(id)
		call_deferred("refresh_authority_state")

var animation_player: AnimationPlayer
var movement_body: CharacterBody3D
var customization: AvatarCustomization
var third_person_camera: ThirdPersonCamera

var char_name: String = "noName"
var skin_tone: Color = Color("f2b089")
var _suppress_customization_broadcast: bool = false
var last_customization_json: String = ""
var height: float:
	get:
		if customization:
			return customization.height
		return 1.0
	set(value):
		set_height(value)
var polygons: Array[MeshInstance3D]:
	get:
		if customization:
			return customization.polygons
		return []


func _ready() -> void:
	animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	movement_body = get_node_or_null("Armature") as CharacterBody3D
	customization = get_node_or_null("AvatarCustomization") as AvatarCustomization
	third_person_camera = get_node_or_null("ThirdPersonCamera") as ThirdPersonCamera

	if customization:
		customization.customized.connect(_on_customization_changed)
	else:
		printerr("AvatarCustomization node is missing from Avatar scene.")

	if third_person_camera and movement_body:
		third_person_camera.set_target(movement_body)

	refresh_authority_state()


func _on_customization_changed() -> void:
	customized.emit()


func refresh_authority_state() -> void:
	var local_player := player_id == multiplayer.get_unique_id()

	if local_player:
		if not customized.is_connected(_on_customized_send):
			customized.connect(_on_customized_send)
		sync_customization_from_local_file()
	else:
		if customized.is_connected(_on_customized_send):
			customized.disconnect(_on_customized_send)

	if local_player and third_person_camera:
		third_person_camera.make_current()


func play_anim_once(anim_name: String) -> void:
	if not is_instance_valid(animation_player):
		return
	if not animation_player.has_animation(anim_name):
		return
	animation_player.play(anim_name)
	await animation_player.animation_finished
	if animation_player.has_animation("Idle"):
		animation_player.play("Idle")
	elif animation_player.has_animation("idle"):
		animation_player.play("idle")


func set_height(new_height: float) -> void:
	if customization:
		customization.set_height(new_height)


func get_material() -> ShaderMaterial:
	if customization:
		return customization.get_material()
	return null


func get_polygons_material() -> ShaderMaterial:
	if customization:
		return customization.get_polygons_material()
	return null


func set_color(option_name: String, new_color: Color) -> void:
	if customization:
		customization.set_color(option_name, new_color)


func get_color(option_name: String) -> Color:
	if customization:
		return customization.get_color(option_name)
	return Color.WHITE


func get_available_color_options() -> Array[String]:
	if customization:
		return customization.get_available_color_options()
	return []


func change_polygon_texture(polygon_name: String, texture_path: String) -> void:
	if customization:
		customization.change_polygon_texture(polygon_name, texture_path)


static func store_save(character: Avatar) -> void:
	if character and character.customization:
		character.customization.store_save()


static func load_save(character: Avatar, path: String = "") -> void:
	if not character or not character.customization:
		return
	if path.is_empty():
		character.customization.load_save()
	else:
		character.customization.load_save(path)


func _on_customized_send() -> void:
	if _suppress_customization_broadcast:
		return
	if not is_multiplayer_authority():
		return
	if not customization:
		return

	var json_string := customization.read_customization_json()
	if json_string.is_empty():
		return

	last_customization_json = json_string
	_rpc_apply_customization.rpc(json_string)


func sync_customization_from_local_file() -> void:
	if not customization:
		return

	var json_string := customization.read_customization_json()
	if json_string.is_empty():
		return

	_suppress_customization_broadcast = true
	customization.apply_customization_from_json(json_string)
	_suppress_customization_broadcast = false
	last_customization_json = json_string
	_rpc_apply_customization.rpc(json_string)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_customization(json_string: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != player_id:
		return
	if json_string.is_empty():
		return
	if not customization:
		return

	last_customization_json = json_string
	_suppress_customization_broadcast = true
	customization.apply_customization_from_json(json_string)
	_suppress_customization_broadcast = false
