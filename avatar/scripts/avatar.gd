class_name Avatar
extends Node3D

signal customized
signal light_melee_started
signal heavy_melee_started
signal light_melee_hit(target_damageable_id: int, damage: int)
signal heavy_melee_hit(target_damageable_id: int, damage: int)
signal run_started(speed: float)
signal run_stopped
signal parry_started
signal parry_ended
signal stun_started
signal stun_ended
signal damaged(amount: int, current_hp: int)
signal died
signal revived

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
var health_bar: AvatarHealthBar
var melee_controller: AvatarMeleeController
var gun_controller: AvatarGunController
var inventory: Inventory
var inventory_debug_ui: AvatarInventoryDebugUi
var _hit_flash_tween: Tween
var _hit_flash_peak: float = 1.0
var _hit_flash_in_duration: float = 0.04
var _hit_flash_out_duration: float = 0.18
@export var parry_fx_path: NodePath = NodePath("Armature/ParryFX")
@export var heavy_melee_hold_threshold: float = 0.25
@export var parry_counter_stun_duration: float = 1.5
@export var show_combat_debug: bool = true
@export var auto_equip_test_beretta: bool = true

const ATTACK_TYPE_QUICK: int = 0
const ATTACK_TYPE_HEAVY: int = 1

var _melee_press_time_ms: int = -1
var _melee_pressed: bool = false
var _heavy_melee_triggered: bool = false
var _debug_layer: CanvasLayer
var _debug_label: Label
var _applying_network_combat_state: bool = false
var _applying_network_inventory_state: bool = false
var _vfx_is_running: bool = false
@export var run_vfx_speed_threshold: float = 0.15

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

var _network_hp: int = 100
var network_hp: int:
	get:
		return _network_hp
	set(value):
		var clamped := maxi(value, 0)
		if _network_hp == clamped:
			return
		_network_hp = clamped
		if _is_local_controlled():
			return
		_apply_network_health_state()

var _network_max_hp: int = 100
var network_max_hp: int:
	get:
		return _network_max_hp
	set(value):
		var clamped := maxi(value, 1)
		if _network_max_hp == clamped:
			return
		_network_max_hp = clamped
		if _is_local_controlled():
			return
		_apply_network_health_state()

var _network_display_name: String = ""
var network_display_name: String:
	get:
		return _network_display_name
	set(value):
		var resolved := value.strip_edges()
		if _network_display_name == resolved:
			return
		_network_display_name = resolved
		if _is_local_controlled():
			return
		if not resolved.is_empty():
			char_name = resolved
		_apply_display_name_to_health_bar()

var _network_inventory_slots_json: String = "[]"
var network_inventory_slots_json: String:
	get:
		return _network_inventory_slots_json
	set(value):
		if _network_inventory_slots_json == value:
			return
		_network_inventory_slots_json = value
		if _is_local_controlled():
			return
		_apply_network_inventory_state()

var _network_inventory_money: int = 0
var network_inventory_money: int:
	get:
		return _network_inventory_money
	set(value):
		var clamped: int = maxi(value, 0)
		if _network_inventory_money == clamped:
			return
		_network_inventory_money = clamped
		if _is_local_controlled():
			return
		_apply_network_inventory_state()

var _network_gun_equipped_item_id: String = ""
var network_gun_equipped_item_id: String:
	get:
		return _network_gun_equipped_item_id
	set(value):
		var resolved: String = value.strip_edges()
		if _network_gun_equipped_item_id == resolved:
			return
		_network_gun_equipped_item_id = resolved
		if _is_local_controlled():
			return
		if gun_controller != null:
			gun_controller.apply_network_equipped(StringName(resolved))

var _network_gun_is_aiming: bool = false
var network_gun_is_aiming: bool:
	get:
		return _network_gun_is_aiming
	set(value):
		if _network_gun_is_aiming == value:
			return
		_network_gun_is_aiming = value
		if _is_local_controlled():
			return
		if gun_controller != null:
			gun_controller.apply_network_aiming(value)

var _network_gun_aim_target_position: Vector3 = Vector3.ZERO
var network_gun_aim_target_position: Vector3:
	get:
		return _network_gun_aim_target_position
	set(value):
		if _network_gun_aim_target_position.is_equal_approx(value):
			return
		_network_gun_aim_target_position = value
		if _is_local_controlled():
			return
		if gun_controller != null:
			gun_controller.apply_network_aim_target(value)

var display_name: String:
	get:
		return char_name
	set(value):
		var resolved := value.strip_edges()
		char_name = resolved if not resolved.is_empty() else "Player_%d" % player_id
		_apply_display_name_to_health_bar()

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
	add_to_group("Damageable")
	animation_player = get_node_or_null("AnimationPlayer") as AvatarAnimations
	movement_body = get_node_or_null("Armature") as CharacterBody3D
	customization = get_node_or_null("AvatarCustomization") as AvatarCustomization
	third_person_camera = get_node_or_null("ThirdPersonCamera") as ThirdPersonCamera
	combat = get_node_or_null("CharacterCombat") as CharacterCombat
	health_bar = get_node_or_null("HealthBar") as AvatarHealthBar
	melee_controller = get_node_or_null("MeleeController") as AvatarMeleeController
	gun_controller = get_node_or_null("GunController") as AvatarGunController
	inventory = get_node_or_null("Inventory") as Inventory
	inventory_debug_ui = get_node_or_null("InventoryDebugUI") as AvatarInventoryDebugUi
	parry_fx = get_node_or_null(parry_fx_path) as Node3D
	if not parry_fx:
		parry_fx = find_child("ParryFX", true, false) as Node3D
	_warn_on_skeleton_scale_issues()
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
		if not combat.hp_changed.is_connected(_on_hp_changed):
			combat.hp_changed.connect(_on_hp_changed)
		if not combat.damaged.is_connected(_on_damaged):
			combat.damaged.connect(_on_damaged)
		_on_combat_state_changed(combat.state, combat.state)
		_on_hp_changed(combat.hp, combat.max_hp)
	if not parry_fx:
		printerr("ParryFX node is missing from Avatar scene.")
	if not health_bar:
		printerr("HealthBar node is missing from Avatar scene.")
	if not melee_controller:
		printerr("MeleeController node is missing from Avatar scene.")
	if not gun_controller:
		printerr("GunController node is missing from Avatar scene.")
	if not inventory:
		printerr("Inventory node is missing from Avatar scene.")
	else:
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)
		if not inventory.money_changed.is_connected(_on_inventory_money_changed):
			inventory.money_changed.connect(_on_inventory_money_changed)
	if not inventory_debug_ui:
		printerr("InventoryDebugUI node is missing from Avatar scene.")

	_auto_grant_and_equip_test_beretta()

	_setup_debug_overlay()
	if combat:
		network_combat_state = combat.state
		network_hp = combat.hp
		network_max_hp = combat.max_hp
	if char_name == "noName":
		char_name = "Player_%d" % player_id
	network_display_name = char_name
	_apply_display_name_to_health_bar()
	if inventory:
		network_inventory_slots_json = inventory.serialize_slots_json()
		network_inventory_money = inventory.get_money()
	if gun_controller != null:
		network_gun_equipped_item_id = gun_controller.get_equipped_item_id()
		network_gun_is_aiming = gun_controller.is_aiming()
		network_gun_aim_target_position = gun_controller.get_aim_target_position()
	_apply_network_inventory_state()
	refresh_authority_state()


func _exit_tree() -> void:
	var should_release_mouse: bool = _is_local_controlled()
	if not should_release_mouse:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _apply_player_authority() -> void:
	if is_instance_valid(movement_body):
		movement_body.set_multiplayer_authority(_player_id)
	var player_input := get_node_or_null("PlayerInput")
	if player_input:
		player_input.set_multiplayer_authority(_player_id)
	var state_sync := get_node_or_null("StateSync")
	if state_sync:
		state_sync.set_multiplayer_authority(_player_id)


func _warn_on_skeleton_scale_issues() -> void:
	var skeleton_node: Skeleton3D = get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton_node == null:
		return
	for bone_index in range(skeleton_node.get_bone_count()):
		var rest_transform: Transform3D = skeleton_node.get_bone_rest(bone_index)
		var rest_scale: Vector3 = rest_transform.basis.get_scale()
		if not _is_unit_scale(rest_scale):
			var bone_name: String = skeleton_node.get_bone_name(bone_index)
			push_warning("Non-unit rest scale on bone %s: %s" % [bone_name, rest_scale])
		if skeleton_node.has_method("get_bone_pose_scale"):
			var pose_scale_variant: Variant = skeleton_node.call("get_bone_pose_scale", bone_index)
			if typeof(pose_scale_variant) == TYPE_VECTOR3:
				var pose_scale: Vector3 = pose_scale_variant as Vector3
				if not _is_unit_scale(pose_scale):
					var pose_bone_name: String = skeleton_node.get_bone_name(bone_index)
					push_warning("Non-unit pose scale on bone %s: %s" % [pose_bone_name, pose_scale])


func _is_unit_scale(value: Vector3) -> bool:
	return is_equal_approx(value.x, 1.0) and is_equal_approx(value.y, 1.0) and is_equal_approx(value.z, 1.0)


func _on_customization_changed() -> void:
	customized.emit()


func _auto_grant_and_equip_test_beretta() -> void:
	if not auto_equip_test_beretta:
		return
	if inventory == null:
		return
	if gun_controller == null:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var beretta_item_id: String = String(AvatarGunController.ITEM_ID_BERETTA)
	if not inventory.has_item(beretta_item_id, 1):
		inventory.try_grant_item(beretta_item_id, 1, {"source": "auto_test_loadout"})
	gun_controller.equip_item(AvatarGunController.ITEM_ID_BERETTA)


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
	if inventory_debug_ui:
		inventory_debug_ui.set_local_player_active(local_player)
	if health_bar:
		health_bar.set_hide_for_local_player(local_player)


func _process(_delta: float) -> void:
	var is_local := _is_local_controlled()
	var speed_for_vfx: float = 0.0
	if is_local:
		if is_instance_valid(animation_player):
			network_animation_state = StringName(animation_player.get_desired_tree_state_name())
		if is_instance_valid(movement_body):
			network_move_speed = movement_body.get_horizontal_speed()
			speed_for_vfx = network_move_speed
		if gun_controller != null:
			gun_controller.set_aiming(Input.is_action_pressed("aim"))
			if Input.is_action_just_pressed("shoot"):
				gun_controller.request_fire_once()
			network_gun_equipped_item_id = gun_controller.get_equipped_item_id()
			network_gun_is_aiming = gun_controller.is_aiming()
			network_gun_aim_target_position = gun_controller.get_aim_target_position()
		network_display_name = char_name
	else:
		speed_for_vfx = _network_move_speed

	_update_run_vfx_state(speed_for_vfx)

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


func _on_combat_state_changed(previous_state: int, new_state: int) -> void:
	var is_actual_transition: bool = previous_state != new_state
	if multiplayer.is_server() and not _is_local_controlled() and is_actual_transition:
		_send_combat_state_sync_to_owner(new_state)
	if is_actual_transition:
		if new_state == CharacterCombat.CombatState.QUICK_MELEE:
			light_melee_started.emit()
		elif new_state == CharacterCombat.CombatState.HEAVY_MELEE:
			heavy_melee_started.emit()
		if new_state == CharacterCombat.CombatState.PARRYING:
			parry_started.emit()
		if previous_state == CharacterCombat.CombatState.PARRYING and new_state != CharacterCombat.CombatState.PARRYING:
			parry_ended.emit()
		if new_state == CharacterCombat.CombatState.STUNNED:
			stun_started.emit()
		if previous_state == CharacterCombat.CombatState.STUNNED and new_state != CharacterCombat.CombatState.STUNNED:
			stun_ended.emit()
		if new_state == CharacterCombat.CombatState.DEAD:
			died.emit()
		if previous_state == CharacterCombat.CombatState.DEAD and new_state == CharacterCombat.CombatState.READY:
			revived.emit()
	if parry_fx:
		parry_fx.visible = new_state == CharacterCombat.CombatState.PARRYING
	if health_bar:
		var stunned_state: bool = new_state == CharacterCombat.CombatState.STUNNED
		health_bar.set_stunned(stunned_state)
	if melee_controller:
		if new_state == CharacterCombat.CombatState.QUICK_MELEE and combat:
			melee_controller.begin_quick_swing_window(combat.quick_melee_duration)
		elif new_state == CharacterCombat.CombatState.HEAVY_MELEE and combat:
			melee_controller.begin_heavy_swing_window(combat.heavy_melee_duration)
		else:
			melee_controller.anim_disable_quick_hitbox()
			melee_controller.anim_disable_heavy_hitbox()
			melee_controller.anim_clear_melee_hit_cache()
	if _applying_network_combat_state:
		return
	if _is_local_controlled():
		network_combat_state = new_state


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.set_health(current_hp, max_hp)
	if _is_local_controlled():
		network_hp = current_hp
		network_max_hp = max_hp


func _on_damaged(_amount: int, _current_hp: int) -> void:
	damaged.emit(_amount, _current_hp)
	_play_hit_flash()


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


func _apply_network_health_state() -> void:
	var safe_max := maxi(_network_max_hp, 1)
	var safe_hp := clampi(_network_hp, 0, safe_max)
	var previous_hp: int = safe_hp

	if combat:
		previous_hp = combat.hp
		var hp_changed := combat.hp != safe_hp or combat.max_hp != safe_max
		combat.max_hp = safe_max
		combat.hp = safe_hp
		if hp_changed:
			combat.hp_changed.emit(combat.hp, combat.max_hp)

	if health_bar:
		health_bar.set_health(safe_hp, safe_max)
	if safe_hp < previous_hp:
		damaged.emit(previous_hp - safe_hp, safe_hp)
		_play_hit_flash()


func _apply_display_name_to_health_bar() -> void:
	if not health_bar:
		return
	var resolved_name := char_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Player_%d" % player_id
	health_bar.set_player_name(resolved_name)


func _on_inventory_changed() -> void:
	if inventory == null:
		return
	if _applying_network_inventory_state:
		return
	if not multiplayer.is_server() and not _is_local_controlled():
		return
	network_inventory_slots_json = inventory.serialize_slots_json()
	network_inventory_money = inventory.get_money()
	if multiplayer.is_server():
		_send_inventory_sync_to_owner(network_inventory_slots_json, network_inventory_money)


func _on_inventory_money_changed(_new_money: int) -> void:
	_on_inventory_changed()


func _apply_network_inventory_state() -> void:
	if inventory == null:
		return
	if multiplayer.is_server():
		return
	if _is_local_controlled():
		return
	_applying_network_inventory_state = true
	inventory.apply_snapshot_from_network(_network_inventory_slots_json, _network_inventory_money)
	_applying_network_inventory_state = false


func _send_inventory_sync_to_owner(slots_json: String, money_value: int) -> void:
	var local_peer_id: int = _get_local_peer_id_if_connected()
	if player_id <= 0:
		return
	if player_id == local_peer_id:
		return
	if not _is_connected_peer(player_id):
		return
	_rpc_sync_inventory.rpc_id(player_id, slots_json, money_value)


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


func equip_beretta() -> bool:
	if gun_controller == null:
		return false
	return gun_controller.equip_item(AvatarGunController.ITEM_ID_BERETTA)


func unequip_weapon() -> void:
	if gun_controller == null:
		return
	gun_controller.unequip_current()


func try_buy_beretta(price: int) -> bool:
	if gun_controller == null:
		return false
	return gun_controller.try_buy_beretta(price)


func try_drop_beretta() -> bool:
	if gun_controller == null:
		return false
	return gun_controller.try_drop_beretta()


func start_quick_melee() -> bool:
	if not combat:
		return false
	var started: bool = combat.start_quick_melee()
	return started


func start_heavy_melee() -> bool:
	if not combat:
		return false
	var started: bool = combat.start_heavy_melee()
	return started


func start_parry() -> bool:
	return combat.start_parry() if combat else false


func stun(duration: float = -1.0) -> bool:
	return combat.stun(duration) if combat else false


func apply_damage(amount: int) -> int:
	return combat.apply_damage(amount) if combat else 0


func can_receive_damage() -> bool:
	if combat == null:
		return false
	return combat.state != CharacterCombat.CombatState.DEAD


func get_damageable_id() -> int:
	return player_id


func request_melee_damage(target_avatar: Avatar, amount: int, attack_type: int, swing_token: int) -> void:
	if target_avatar == null:
		return
	request_melee_damage_to_damageable(target_avatar.player_id, amount, attack_type, swing_token)


func request_melee_damage_to_damageable(target_damageable_id: int, amount: int, attack_type: int, swing_token: int) -> void:
	if not _is_local_controlled():
		return
	if target_damageable_id <= 0:
		return
	if amount <= 0:
		return
	if swing_token <= 0:
		return
	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.is_server():
		_server_apply_melee_damage(target_damageable_id, amount, attack_type, swing_token)
		return

	var multiplayer_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if multiplayer_peer == null:
		return
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var host_id: int = _resolve_host_peer_id()
	if host_id <= 0:
		return
	if not _is_connected_peer(host_id):
		return
	_rpc_request_melee_damage.rpc_id(host_id, target_damageable_id, amount, attack_type, swing_token)


func anim_enable_quick_hitbox() -> void:
	if melee_controller:
		melee_controller.anim_enable_quick_hitbox()


func anim_disable_quick_hitbox() -> void:
	if melee_controller:
		melee_controller.anim_disable_quick_hitbox()


func anim_enable_heavy_hitbox() -> void:
	if melee_controller:
		melee_controller.anim_enable_heavy_hitbox()


func anim_disable_heavy_hitbox() -> void:
	if melee_controller:
		melee_controller.anim_disable_heavy_hitbox()


func anim_clear_melee_hit_cache() -> void:
	if melee_controller:
		melee_controller.anim_clear_melee_hit_cache()


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

	var local_peer_id: int = -1
	if multiplayer.has_multiplayer_peer():
		var peer: MultiplayerPeer = multiplayer.multiplayer_peer
		if peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			local_peer_id = multiplayer.get_unique_id()

	_debug_label.text = "\n".join([
		"Combat Debug",
		"Player Local ID: %d | Avatar Player ID: %d" % [local_peer_id, player_id],
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
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return true
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return true

	var local_id: int = multiplayer.get_unique_id()
	if local_id <= 0:
		return true
	if player_id == local_id:
		return true
	if movement_body and movement_body.is_multiplayer_authority():
		return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_melee_damage(target_damageable_id: int, amount: int, attack_type: int, swing_token: int) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0:
		return
	if swing_token <= 0:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != player_id:
		return

	_server_apply_melee_damage(target_damageable_id, amount, attack_type, swing_token)


func _server_apply_melee_damage(target_damageable_id: int, amount: int, attack_type: int, swing_token: int) -> void:
	if not multiplayer.is_server():
		return
	if combat == null:
		return
	if melee_controller == null:
		return
	if swing_token <= 0:
		return

	var target_damageable: Node = _find_damageable_by_id(target_damageable_id)
	if target_damageable == null:
		return
	if target_damageable == self:
		return

	if attack_type != ATTACK_TYPE_QUICK and attack_type != ATTACK_TYPE_HEAVY:
		return

	var expected_damage: int = melee_controller.get_damage_for_attack_type(attack_type)
	if amount != expected_damage:
		return
	if not melee_controller.is_swing_token_valid_for_active_window(attack_type, swing_token):
		return

	var overlap_valid: bool = melee_controller.can_hit_target(target_damageable, attack_type)
	var range_valid: bool = melee_controller.is_target_within_fallback_range(target_damageable, attack_type)
	if not overlap_valid and not range_valid:
		return

	if target_damageable.has_method("can_receive_damage"):
		var can_receive_result: Variant = target_damageable.call("can_receive_damage")
		if typeof(can_receive_result) == TYPE_BOOL and not bool(can_receive_result):
			return

	if target_damageable is Avatar:
		var target_avatar: Avatar = target_damageable as Avatar
		if target_avatar.combat and target_avatar.combat.state == CharacterCombat.CombatState.PARRYING:
			var should_stun_attacker: bool = combat.state != CharacterCombat.CombatState.STUNNED
			if should_stun_attacker:
				var stun_duration: float = maxf(parry_counter_stun_duration, 0.01)
				stun(stun_duration)
			return

	melee_controller.mark_target_hit(target_damageable, attack_type)
	var applied_result: Variant = 0
	if target_damageable.has_method("apply_damage_from_attacker"):
		applied_result = target_damageable.call("apply_damage_from_attacker", amount, player_id)
	else:
		applied_result = target_damageable.call("apply_damage", amount)
	var applied_damage: int = 0
	if typeof(applied_result) == TYPE_INT:
		applied_damage = int(applied_result)
	if applied_damage <= 0:
		return
	_emit_confirmed_melee_hit_event(attack_type, target_damageable_id, applied_damage)
	if multiplayer.has_multiplayer_peer():
		_rpc_broadcast_melee_hit.rpc(attack_type, target_damageable_id, applied_damage)
	if target_damageable is Avatar:
		var damaged_avatar: Avatar = target_damageable as Avatar
		if damaged_avatar.combat:
			var synced_hp: int = damaged_avatar.combat.hp
			var synced_max_hp: int = damaged_avatar.combat.max_hp
			damaged_avatar._send_health_sync_to_owner(synced_hp, synced_max_hp)


func _send_combat_state_sync_to_owner(new_state: int) -> void:
	var local_peer_id: int = _get_local_peer_id_if_connected()
	if player_id <= 0:
		return
	if player_id == local_peer_id:
		return
	if not _is_connected_peer(player_id):
		return
	_rpc_sync_combat_state.rpc_id(player_id, new_state)


func _send_health_sync_to_owner(new_hp: int, new_max_hp: int) -> void:
	var local_peer_id: int = _get_local_peer_id_if_connected()
	if player_id <= 0:
		return
	if player_id == local_peer_id:
		return
	if not _is_connected_peer(player_id):
		return
	_rpc_sync_health.rpc_id(player_id, new_hp, new_max_hp)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_combat_state(new_state: int) -> void:
	if multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var host_id: int = _resolve_host_peer_id()
	if sender_id != host_id:
		return

	_apply_synced_combat_state(new_state)


func _apply_synced_combat_state(new_state: int) -> void:
	_network_combat_state = new_state
	_apply_network_combat_state(new_state)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_health(new_hp: int, new_max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var host_id: int = _resolve_host_peer_id()
	if sender_id != host_id:
		return

	_apply_synced_health(new_hp, new_max_hp)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_inventory(slots_json: String, money_value: int) -> void:
	if multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var host_id: int = _resolve_host_peer_id()
	if sender_id != host_id:
		return
	_apply_synced_inventory(slots_json, money_value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_broadcast_melee_hit(attack_type: int, target_damageable_id: int, damage: int) -> void:
	if multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var host_id: int = _resolve_host_peer_id()
	if sender_id != host_id:
		return
	_emit_confirmed_melee_hit_event(attack_type, target_damageable_id, damage)


func _apply_synced_health(new_hp: int, new_max_hp: int) -> void:
	var safe_max: int = maxi(new_max_hp, 1)
	var safe_hp: int = clampi(new_hp, 0, safe_max)

	_network_max_hp = safe_max
	_network_hp = safe_hp

	if combat:
		var previous_hp: int = combat.hp
		var hp_changed: bool = combat.hp != safe_hp or combat.max_hp != safe_max
		combat.max_hp = safe_max
		combat.hp = safe_hp
		if hp_changed:
			combat.hp_changed.emit(combat.hp, combat.max_hp)
		if safe_hp < previous_hp:
			damaged.emit(previous_hp - safe_hp, safe_hp)
	elif health_bar:
		health_bar.set_health(safe_hp, safe_max)


func _apply_synced_inventory(slots_json: String, money_value: int) -> void:
	_network_inventory_slots_json = slots_json
	_network_inventory_money = maxi(money_value, 0)
	if inventory == null:
		return
	_applying_network_inventory_state = true
	inventory.apply_snapshot_from_network(_network_inventory_slots_json, _network_inventory_money)
	_applying_network_inventory_state = false


func _update_run_vfx_state(speed_value: float) -> void:
	var should_run: bool = speed_value >= run_vfx_speed_threshold
	if combat != null:
		should_run = should_run and combat.state == CharacterCombat.CombatState.READY
	if _vfx_is_running == should_run:
		return
	_vfx_is_running = should_run
	if should_run:
		run_started.emit(speed_value)
	else:
		run_stopped.emit()


func _emit_confirmed_melee_hit_event(attack_type: int, target_damageable_id: int, damage: int) -> void:
	if damage <= 0:
		return
	if attack_type == ATTACK_TYPE_HEAVY:
		heavy_melee_hit.emit(target_damageable_id, damage)
		return
	light_melee_hit.emit(target_damageable_id, damage)


func _find_damageable_by_id(target_damageable_id: int) -> Node:
	var world_root: Node = get_tree().root
	var stack: Array[Node] = []
	stack.push_back(world_root)

	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node.has_method("get_damageable_id") and node.has_method("apply_damage"):
			var resolved_id_value: Variant = node.call("get_damageable_id")
			if typeof(resolved_id_value) == TYPE_INT and int(resolved_id_value) == target_damageable_id:
				return node
		var children: Array = node.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child as Node)

	return null


func _resolve_host_peer_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return -1

	var multiplayer_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if multiplayer_peer == null:
		return -1
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return -1

	var default_host_id: int = 1
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	if connected_peers.size() <= 0:
		return -1

	var session_host_id: int = _resolve_session_host_peer_id()
	if session_host_id > 0 and connected_peers.has(session_host_id):
		return session_host_id

	if connected_peers.has(default_host_id):
		return default_host_id

	if connected_peers.size() == 1:
		return int(connected_peers[0])

	var resolved_host_id: int = int(connected_peers[0])
	for peer_id_variant in connected_peers:
		var peer_id: int = int(peer_id_variant)
		if peer_id < resolved_host_id:
			resolved_host_id = peer_id
	return resolved_host_id


func _is_connected_peer(peer_id: int) -> bool:
	if peer_id <= 0:
		return false
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	return connected_peers.has(peer_id)


func _get_local_peer_id_if_connected() -> int:
	if not multiplayer.has_multiplayer_peer():
		return -1

	var multiplayer_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if multiplayer_peer == null:
		return -1
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return -1

	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return -1
	return local_peer_id


func _resolve_session_host_peer_id() -> int:
	var session_manager: Node = get_node_or_null("/root/SessionManager")
	if session_manager == null:
		return -1

	var host_value: Variant = session_manager.get("host_peer_id")
	if typeof(host_value) != TYPE_INT:
		return -1

	var host_id: int = int(host_value)
	if host_id <= 0:
		return -1
	return host_id


func _play_hit_flash() -> void:
	_set_avatar_hit_glow(0.0)
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()

	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(_set_avatar_hit_glow, 0.0, _hit_flash_peak, _hit_flash_in_duration)
	_hit_flash_tween.tween_method(_set_avatar_hit_glow, _hit_flash_peak, 0.0, _hit_flash_out_duration)


func _set_avatar_hit_glow(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	var materials: Array[ShaderMaterial] = _collect_avatar_shader_materials()
	for material in materials:
		material.set_shader_parameter("hit_glow", clamped)


func _collect_avatar_shader_materials() -> Array[ShaderMaterial]:
	var found: Array[ShaderMaterial] = []
	if customization == null:
		return found

	var meshes: Array[MeshInstance3D] = customization.mesh_instances
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue

		if mesh.material_override is ShaderMaterial:
			var override_shader: ShaderMaterial = mesh.material_override as ShaderMaterial
			if not found.has(override_shader):
				found.append(override_shader)

		var mesh_resource: Mesh = mesh.mesh
		if mesh_resource == null:
			continue
		var surface_count: int = mesh_resource.get_surface_count()
		for surface_index in range(surface_count):
			var surface_material: Material = mesh.get_surface_override_material(surface_index)
			if surface_material == null:
				surface_material = mesh_resource.surface_get_material(surface_index)
			if surface_material is ShaderMaterial:
				var shader_material: ShaderMaterial = surface_material as ShaderMaterial
				if not found.has(shader_material):
					found.append(shader_material)

	return found


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
