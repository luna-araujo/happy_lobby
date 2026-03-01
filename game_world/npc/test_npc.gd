class_name TestNpc
extends CharacterBody3D

const DUCK_HIT_SHADER: Shader = preload("res://avatar/shaders/avatar.gdshader")
const COIN_REWARD_VFX_SCENE: PackedScene = preload("res://game_world/effects/coin_reward_vfx.tscn")

@export var npc_id: int = 0
@export var display_name: String = ""
@export var move_speed: float = 3.2
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var turn_speed: float = 6.0
@export var wander_radius: float = 18.0
@export var target_repath_min_seconds: float = 1.0
@export var target_repath_max_seconds: float = 2.8
@export var respawn_delay_seconds: float = 2.0
@export var gravity_scale: float = 1.0
@export var kill_reward_money: int = 5

var combat: CharacterCombat
var health_bar: AvatarHealthBar
var _wander_center: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _next_repath_time_seconds: float = 0.0
var _respawn_pending: bool = false
var _hit_flash_tween: Tween
var _hit_flash_peak: float = 1.0
var _hit_flash_in_duration: float = 0.04
var _hit_flash_out_duration: float = 0.18
var _duck_hit_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	add_to_group("Damageable")
	add_to_group("TestNpc")

	combat = get_node_or_null("CharacterCombat") as CharacterCombat
	health_bar = get_node_or_null("HealthBar") as AvatarHealthBar

	if combat != null:
		if not combat.died.is_connected(_on_combat_died):
			combat.died.connect(_on_combat_died)
		if not combat.hp_changed.is_connected(_on_hp_changed):
			combat.hp_changed.connect(_on_hp_changed)
		if not combat.state_changed.is_connected(_on_state_changed):
			combat.state_changed.connect(_on_state_changed)
		if not combat.damaged.is_connected(_on_damaged):
			combat.damaged.connect(_on_damaged)

	if display_name.strip_edges().is_empty():
		display_name = "Duck_%d" % npc_id

	_setup_duck_hit_shader()
	_set_hit_glow(0.0)

	if health_bar != null:
		health_bar.set_player_name(display_name)

	_wander_center = global_position
	_pick_new_wander_target()
	if combat != null:
		_on_hp_changed(combat.hp, combat.max_hp)
		_on_state_changed(-1, combat.state)
	else:
		_on_hp_changed(100, 100)
		_on_state_changed(-1, CharacterCombat.CombatState.READY)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_update_wander_motion(delta)


func _process(_delta: float) -> void:
	if health_bar == null:
		return
	if combat == null:
		return
	health_bar.set_health(combat.hp, combat.max_hp)
	var is_stunned: bool = combat.state == CharacterCombat.CombatState.STUNNED
	health_bar.set_stunned(is_stunned)


func can_receive_damage() -> bool:
	if combat == null:
		return false
	return combat.state != CharacterCombat.CombatState.DEAD


func get_damageable_id() -> int:
	return npc_id


func apply_damage(amount: int) -> int:
	if combat == null:
		return 0
	return combat.apply_damage(amount)


func apply_damage_from_attacker(amount: int, attacker_player_id: int) -> int:
	if combat == null:
		return 0
	var was_alive: bool = combat.state != CharacterCombat.CombatState.DEAD
	var previous_hp: int = combat.hp
	var applied_damage: int = combat.apply_damage(amount)
	if applied_damage <= 0:
		return 0
	var is_now_dead: bool = combat.state == CharacterCombat.CombatState.DEAD or combat.hp <= 0
	var became_dead: bool = was_alive and previous_hp > 0 and is_now_dead
	if became_dead:
		_grant_kill_reward(attacker_player_id)
	return applied_damage


func set_wander_center(center_position: Vector3, radius: float) -> void:
	_wander_center = center_position
	wander_radius = maxf(radius, 1.0)
	_pick_new_wander_target()


func _update_wander_motion(delta: float) -> void:
	if combat == null:
		return

	var is_dead: bool = combat.state == CharacterCombat.CombatState.DEAD
	var is_stunned: bool = combat.state == CharacterCombat.CombatState.STUNNED
	var can_move: bool = not is_dead and not is_stunned

	if not is_on_floor():
		var gravity: Vector3 = get_gravity() * maxf(gravity_scale, 0.01)
		velocity += gravity * delta

	if can_move:
		var now_seconds: float = Time.get_ticks_msec() / 1000.0
		if now_seconds >= _next_repath_time_seconds:
			_pick_new_wander_target()

		var to_target: Vector3 = _wander_target - global_position
		to_target.y = 0.0
		var has_target: bool = to_target.length_squared() > 0.04
		var desired_velocity: Vector3 = Vector3.ZERO
		if has_target:
			var direction: Vector3 = to_target.normalized()
			desired_velocity = direction * move_speed
			var target_yaw: float = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

		velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	move_and_slide()


func _pick_new_wander_target() -> void:
	var radius: float = maxf(wander_radius, 1.0)
	var offset: Vector3 = Vector3(
		randf_range(-radius, radius),
		0.0,
		randf_range(-radius, radius)
	)
	_wander_target = _wander_center + offset
	var interval_min: float = maxf(target_repath_min_seconds, 0.1)
	var interval_max: float = maxf(target_repath_max_seconds, interval_min)
	var interval: float = randf_range(interval_min, interval_max)
	_next_repath_time_seconds = (Time.get_ticks_msec() / 1000.0) + interval


func _on_combat_died() -> void:
	if _respawn_pending:
		return
	_respawn_pending = true
	if not is_multiplayer_authority():
		return
	_respawn_after_delay()


func _respawn_after_delay() -> void:
	var delay_seconds: float = maxf(respawn_delay_seconds, 0.1)
	await get_tree().create_timer(delay_seconds).timeout
	if is_queued_for_deletion():
		return
	if combat == null:
		return

	if combat.state == CharacterCombat.CombatState.DEAD:
		combat.revive()
	global_position = _random_spawn_point()
	velocity = Vector3.ZERO
	_pick_new_wander_target()
	_respawn_pending = false


func _random_spawn_point() -> Vector3:
	var radius: float = maxf(wander_radius, 1.0)
	var offset: Vector3 = Vector3(
		randf_range(-radius, radius),
		0.0,
		randf_range(-radius, radius)
	)
	return _wander_center + offset


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if health_bar == null:
		return
	health_bar.set_health(current_hp, max_hp)


func _on_state_changed(_previous_state: int, new_state: int) -> void:
	if health_bar == null:
		return
	var is_stunned: bool = new_state == CharacterCombat.CombatState.STUNNED
	health_bar.set_stunned(is_stunned)


func _on_damaged(_amount: int, _current_hp: int) -> void:
	_play_hit_flash()


func _setup_duck_hit_shader() -> void:
	_duck_hit_materials.clear()
	var duck_root: Node3D = get_node_or_null("DuckModel") as Node3D
	if duck_root == null:
		return

	var mesh_nodes: Array = duck_root.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		if not (mesh_node is MeshInstance3D):
			continue
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue

		var duck_material: ShaderMaterial = ShaderMaterial.new()
		duck_material.shader = DUCK_HIT_SHADER
		duck_material.set_shader_parameter("base_color", Color(0.95, 0.84, 0.28, 1.0))
		duck_material.set_shader_parameter("shadow_strength", 0.45)
		duck_material.set_shader_parameter("mid_strength", 0.15)
		duck_material.set_shader_parameter("light_strength", 0.25)
		duck_material.set_shader_parameter("shadow_threshold", 0.25)
		duck_material.set_shader_parameter("light_threshold", 0.65)
		duck_material.set_shader_parameter("rim_threshold", 0.7)
		duck_material.set_shader_parameter("rim_lighten", 0.3)
		duck_material.set_shader_parameter("hit_glow", 0.0)
		mesh_instance.material_override = duck_material
		_duck_hit_materials.append(duck_material)


func _play_hit_flash() -> void:
	_set_hit_glow(0.0)
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()

	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(_set_hit_glow, 0.0, _hit_flash_peak, _hit_flash_in_duration)
	_hit_flash_tween.tween_method(_set_hit_glow, _hit_flash_peak, 0.0, _hit_flash_out_duration)


func _set_hit_glow(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	for shader_material in _duck_hit_materials:
		if not is_instance_valid(shader_material):
			continue
		shader_material.set_shader_parameter("hit_glow", clamped)


func _grant_kill_reward(attacker_player_id: int) -> void:
	if kill_reward_money <= 0:
		return
	if attacker_player_id <= 0:
		return
	if not multiplayer.is_server():
		return
	var attacker_avatar: Avatar = _find_avatar_by_player_id(attacker_player_id)
	if attacker_avatar == null:
		return
	if attacker_avatar.inventory == null:
		return
	attacker_avatar.inventory.add_money(kill_reward_money)
	_rpc_spawn_reward_coin_vfx.rpc(global_position + Vector3.UP * 0.35, attacker_player_id, kill_reward_money)


func _find_avatar_by_player_id(target_player_id: int) -> Avatar:
	var world_root: Node = get_tree().root
	var stack: Array[Node] = []
	stack.push_back(world_root)
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		if current is Avatar:
			var avatar_node: Avatar = current as Avatar
			if avatar_node.player_id == target_player_id:
				return avatar_node
		var children: Array = current.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child)
	return null


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_reward_coin_vfx(spawn_position: Vector3, target_player_id: int, reward_value: int) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var vfx_instance: CoinRewardVfx = COIN_REWARD_VFX_SCENE.instantiate() as CoinRewardVfx
	if vfx_instance == null:
		return
	current_scene.add_child(vfx_instance)
	vfx_instance.start_flight(spawn_position, target_player_id, reward_value)
