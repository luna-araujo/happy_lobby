class_name Avatar
extends Node3D

signal customized

var _player_id: int = 1
var player_id: int:
	get:
		return _player_id
	set(id):
		_player_id = id
		_apply_player_authority()
		call_deferred("refresh_authority_state")

var animation_player: AvatarAnimations
var movement_body: CharacterBody3D
var customization: AvatarCustomization
var third_person_camera: ThirdPersonCamera
var combat: CharacterCombat
var parry_fx: Node3D
@export var parry_fx_path: NodePath = NodePath("Armature/ParryFX")
@export var heavy_melee_hold_threshold: float = 0.25
@export var show_combat_debug: bool = true

var _melee_press_time_ms: int = -1
var _melee_pressed: bool = false
var _heavy_melee_triggered: bool = false
var _debug_layer: CanvasLayer
var _debug_label: Label
var _applying_network_combat_state: bool = false

var _network_animation_state: StringName = &"Locomotion"
var network_animation_state: StringName:
	get:
		return _network_animation_state
	set(value):
		if _network_animation_state == value:
			return
		_network_animation_state = value
		if _is_local_controlled():
			return
		if is_instance_valid(animation_player):
			animation_player.set_network_tree_state(value)

var _network_move_speed: float = 0.0
var network_move_speed: float:
	get:
		return _network_move_speed
	set(value):
		if is_equal_approx(_network_move_speed, value):
			return
		_network_move_speed = value
		if _is_local_controlled():
			return
		if is_instance_valid(animation_player):
			animation_player.set_network_locomotion_speed(value)

var _network_combat_state: int = CharacterCombat.CombatState.READY
var network_combat_state: int:
	get:
		return _network_combat_state
	set(value):
		if _network_combat_state == value:
			return
		_network_combat_state = value
		if _is_local_controlled():
			return
		_apply_network_combat_state(value)

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
	animation_player = get_node_or_null("AnimationPlayer") as AvatarAnimations
	movement_body = get_node_or_null("Armature") as CharacterBody3D
	customization = get_node_or_null("AvatarCustomization") as AvatarCustomization
	third_person_camera = get_node_or_null("ThirdPersonCamera") as ThirdPersonCamera
	combat = get_node_or_null("CharacterCombat") as CharacterCombat
	parry_fx = get_node_or_null(parry_fx_path) as Node3D
	if not parry_fx:
		parry_fx = find_child("ParryFX", true, false) as Node3D
	_apply_player_authority()

	if customization:
		customization.customized.connect(_on_customization_changed)
	else:
		printerr("AvatarCustomization node is missing from Avatar scene.")

	if third_person_camera and movement_body:
		third_person_camera.set_target(movement_body)
	if not combat:
		printerr("CharacterCombat node is missing from Avatar scene.")
	else:
		if not combat.state_changed.is_connected(_on_combat_state_changed):
			combat.state_changed.connect(_on_combat_state_changed)
		_on_combat_state_changed(combat.state, combat.state)
	if not parry_fx:
		printerr("ParryFX node is missing from Avatar scene.")

	_setup_debug_overlay()
	if combat:
		network_combat_state = combat.state
	refresh_authority_state()


func _apply_player_authority() -> void:
	if is_instance_valid(movement_body):
		movement_body.set_multiplayer_authority(_player_id)
	var player_input := get_node_or_null("PlayerInput")
	if player_input:
		player_input.set_multiplayer_authority(_player_id)
	var state_sync := get_node_or_null("StateSync")
	if state_sync:
		state_sync.set_multiplayer_authority(_player_id)


func _on_customization_changed() -> void:
	customized.emit()


func refresh_authority_state() -> void:
	var local_player := _is_local_controlled()

	if local_player:
		if not customized.is_connected(_on_customized_send):
			customized.connect(_on_customized_send)
		sync_customization_from_local_file()
	else:
		if customized.is_connected(_on_customized_send):
			customized.disconnect(_on_customized_send)

	if third_person_camera:
		third_person_camera.set_active(local_player)


func _process(_delta: float) -> void:
	var is_local := _is_local_controlled()
	if is_local:
		if is_instance_valid(animation_player):
			network_animation_state = StringName(animation_player.get_desired_tree_state_name())
		if is_instance_valid(movement_body):
			network_move_speed = movement_body.get_horizontal_speed()
	if not is_local:
		_update_debug_overlay(false)
		return

	if Input.is_action_just_pressed("parry"):
		start_parry()

	if Input.is_action_just_pressed("melee"):
		_melee_press_time_ms = Time.get_ticks_msec()
		_melee_pressed = true
		_heavy_melee_triggered = false

	if Input.is_action_just_released("melee"):
		_melee_press_time_ms = -1
		_melee_pressed = false
		if not _heavy_melee_triggered:
			start_quick_melee()
		_heavy_melee_triggered = false

	if _melee_pressed and not _heavy_melee_triggered and _melee_press_time_ms >= 0 and Input.is_action_pressed("melee"):
		var held_seconds: float = float(Time.get_ticks_msec() - _melee_press_time_ms) / 1000.0
		if held_seconds >= heavy_melee_hold_threshold:
			if start_heavy_melee():
				_heavy_melee_triggered = true

	_update_debug_overlay(true)


func _on_combat_state_changed(_previous_state: int, new_state: int) -> void:
	if parry_fx:
		parry_fx.visible = new_state == CharacterCombat.CombatState.PARRYING
	if _applying_network_combat_state:
		return
	if _is_local_controlled():
		network_combat_state = new_state


func _apply_network_combat_state(new_state: int) -> void:
	if not combat:
		return
	if combat.state == new_state:
		return

	_applying_network_combat_state = true
	var previous_state := combat.state
	combat.state = new_state
	combat.state_changed.emit(previous_state, new_state)
	_applying_network_combat_state = false


func play_anim_once(anim_name: String) -> void:
	if not is_instance_valid(animation_player):
		return
	await animation_player.play_once(StringName(anim_name))


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


func start_punch() -> bool:
	return start_quick_melee()


func start_quick_melee() -> bool:
	return combat.start_quick_melee() if combat else false


func start_heavy_melee() -> bool:
	return combat.start_heavy_melee() if combat else false


func start_parry() -> bool:
	return combat.start_parry() if combat else false


func stun(duration: float = -1.0) -> bool:
	return combat.stun(duration) if combat else false


func apply_damage(amount: int) -> int:
	return combat.apply_damage(amount) if combat else 0


func heal(amount: int) -> int:
	return combat.heal(amount) if combat else 0


func _setup_debug_overlay() -> void:
	if not show_combat_debug:
		return
	if is_instance_valid(_debug_layer):
		return

	_debug_layer = CanvasLayer.new()
	_debug_layer.layer = 100
	_debug_layer.name = "CombatDebugLayer"
	add_child(_debug_layer)

	_debug_label = Label.new()
	_debug_label.name = "CombatDebugLabel"
	_debug_label.position = Vector2(12.0, 12.0)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_debug_layer.add_child(_debug_label)


func _update_debug_overlay(is_local: bool) -> void:
	if not show_combat_debug:
		return
	if not is_instance_valid(_debug_layer) or not is_instance_valid(_debug_label):
		return

	_debug_layer.visible = is_local
	if not is_local:
		return

	var combat_state_name := "NO_COMBAT"
	var hp_text := "n/a"
	var parry_cd := 0.0
	if combat:
		combat_state_name = _combat_state_name(combat.state)
		hp_text = "%d/%d" % [combat.hp, combat.max_hp]
		parry_cd = combat.get_parry_cooldown_remaining()

	var tree_state := ""
	var desired_tree_state := ""
	var current_anim := ""
	if animation_player:
		tree_state = animation_player.get_current_tree_state_name()
		desired_tree_state = animation_player.get_desired_tree_state_name()
		current_anim = String(animation_player.current_animation)

	_debug_label.text = "\n".join([
		"Combat Debug",
		"Player Local ID: %d | Avatar Player ID: %d" % [multiplayer.get_unique_id(), player_id],
		"HP: %s" % hp_text,
		"Combat State: %s" % combat_state_name,
		"Parry CD: %.2fs" % parry_cd,
		"Melee Pressed: %s | Heavy Triggered: %s" % [str(_melee_pressed), str(_heavy_melee_triggered)],
		"Input Melee: %s | Input Parry: %s" % [str(Input.is_action_pressed("melee")), str(Input.is_action_pressed("parry"))],
		"Tree Current: %s | Tree Desired: %s" % [tree_state, desired_tree_state],
		"AnimationPlayer Current: %s" % current_anim
	])


func _combat_state_name(state_value: int) -> String:
	match state_value:
		CharacterCombat.CombatState.READY:
			return "READY"
		CharacterCombat.CombatState.QUICK_MELEE:
			return "QUICK_MELEE"
		CharacterCombat.CombatState.HEAVY_MELEE:
			return "HEAVY_MELEE"
		CharacterCombat.CombatState.PARRYING:
			return "PARRYING"
		CharacterCombat.CombatState.STUNNED:
			return "STUNNED"
		CharacterCombat.CombatState.DEAD:
			return "DEAD"
	return "UNKNOWN(%d)" % state_value


func _is_local_controlled() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	if player_id == multiplayer.get_unique_id():
		return true
	if movement_body and movement_body.is_multiplayer_authority():
		return true
	return false


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
