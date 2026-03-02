class_name CoinRewardVfx
extends Node3D

@export var flight_duration: float = 0.55
@export var arc_height: float = 1.2
@export var initial_height_offset: float = 0.8
@export var coin_base_color: Color = Color(1.0, 0.82, 0.15, 1.0)
@export var coin_emission_color: Color = Color(1.0, 0.86, 0.25, 1.0)
@export var coin_emission_energy: float = 5.5

var target_player_id: int = 0
var reward_amount: int = 0
var _flight_start_position: Vector3 = Vector3.ZERO
var _flight_tween: Tween
var _coin_visual_root: Node3D


func _ready() -> void:
	_coin_visual_root = get_node_or_null("CoinModel") as Node3D
	if _coin_visual_root != null:
		_apply_gold_material_to_coin()
		_coin_visual_root.rotate_y(randf() * TAU)


func start_flight(spawn_position: Vector3, target_id: int, amount: int) -> void:
	global_position = spawn_position + Vector3.UP * initial_height_offset
	_flight_start_position = global_position
	target_player_id = target_id
	reward_amount = maxi(amount, 1)
	_start_flight_tween()


func _process(delta: float) -> void:
	if _coin_visual_root == null:
		return
	var spin_speed: float = 4.8 + minf(float(reward_amount) * 0.08, 2.0)
	_coin_visual_root.rotate_y(spin_speed * delta)


func _start_flight_tween() -> void:
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	var duration: float = maxf(flight_duration, 0.1)
	_flight_tween = create_tween()
	_flight_tween.set_trans(Tween.TRANS_CUBIC)
	_flight_tween.set_ease(Tween.EASE_IN_OUT)
	_flight_tween.tween_method(_update_flight, 0.0, 1.0, duration)
	_flight_tween.finished.connect(_on_flight_finished)


func _update_flight(progress: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var target_position: Vector3 = _resolve_target_position()
	var interpolated: Vector3 = _flight_start_position.lerp(target_position, clamped_progress)
	interpolated.y += sin(clamped_progress * PI) * arc_height
	global_position = interpolated


func _on_flight_finished() -> void:
	if _coin_visual_root != null:
		_coin_visual_root.visible = false
	queue_free()


func _resolve_target_position() -> Vector3:
	var target_avatar: Avatar = _find_avatar_by_player_id(target_player_id)
	if target_avatar != null:
		if target_avatar.movement_body != null:
			return target_avatar.movement_body.global_position + Vector3.UP * 1.4
		return target_avatar.global_position + Vector3.UP * 1.4
	return _flight_start_position + Vector3.UP * 1.0


func _find_avatar_by_player_id(target_id: int) -> Avatar:
	if target_id <= 0:
		return null
	var world_root: Node = get_tree().root
	var stack: Array[Node] = []
	stack.push_back(world_root)
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is Avatar:
			var avatar_node: Avatar = node as Avatar
			if avatar_node.player_id == target_id:
				return avatar_node
		var children: Array = node.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child)
	return null


func _apply_gold_material_to_coin() -> void:
	if _coin_visual_root == null:
		return
	var mesh_nodes: Array[MeshInstance3D] = []
	if _coin_visual_root is MeshInstance3D:
		mesh_nodes.append(_coin_visual_root as MeshInstance3D)
	var discovered_nodes: Array = _coin_visual_root.find_children("*", "MeshInstance3D", true, false)
	for discovered in discovered_nodes:
		if discovered is MeshInstance3D:
			mesh_nodes.append(discovered as MeshInstance3D)
	for mesh_node in mesh_nodes:
		var mesh_instance: MeshInstance3D = mesh_node
		var gold_material: StandardMaterial3D = StandardMaterial3D.new()
		gold_material.albedo_color = coin_base_color
		gold_material.metallic = 1.0
		gold_material.roughness = 0.16
		gold_material.metallic_specular = 1.0
		gold_material.emission_enabled = true
		gold_material.emission = coin_emission_color
		gold_material.emission_energy_multiplier = maxf(coin_emission_energy, 0.0)
		mesh_instance.material_override = gold_material
