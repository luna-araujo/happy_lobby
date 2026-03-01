class_name AvatarGunController
extends Node

const ITEM_ID_BERETTA: StringName = &"items.beretta"

@export var inventory_path: NodePath = NodePath("../Inventory")
@export var combat_path: NodePath = NodePath("../CharacterCombat")
@export var movement_body_path: NodePath = NodePath("../Armature")
@export var skeleton_path: NodePath = NodePath("../Armature/Skeleton3D")
@export var right_hand_path: NodePath = NodePath("../Armature/Skeleton3D/RHand")
@export var aim_target_path: NodePath = NodePath("../WeaponAimTarget")
@export var beretta_scene: PackedScene = preload("res://items/beretta/beretta.tscn")
@export var beretta_local_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var beretta_local_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var beretta_local_scale: Vector3 = Vector3(2.5, 2.5, 2.5)
@export var fire_damage: int = 6
@export var fire_rate_per_second: float = 6.0
@export var max_shoot_distance: float = 180.0
@export var tip_bone_name: StringName = &"R.Hand"
@export var hand_override_forward_distance: float = 0.75
@export var hand_override_right_offset: float = 0.35
@export var hand_override_vertical_offset: float = 1.35
@export var hand_override_look_offset_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var gun_shoot_sfx: AudioStream = preload("res://assets/vfx_samples/audio/sound_hit.wav")
@export var gun_impact_sfx: AudioStream = preload("res://assets/vfx_samples/audio/hit.wav")
@export var gun_hit_vfx_scene: PackedScene = preload("res://avatar/effects/scenes/sample_hit_vfx.tscn")
@export var gun_feedback_volume_db: float = -6.0

var avatar: Avatar
var inventory: Inventory
var combat: CharacterCombat
var movement_body: CharacterBody3D
var skeleton: Skeleton3D
var right_hand_anchor: BoneAttachment3D
var aim_target: Node3D
var beretta_instance: Node3D
var _equipped_item_id: StringName = &""
var _is_aiming: bool = false
var _network_aim_target_position: Vector3 = Vector3.ZERO
var _last_local_fire_request_time_ms: int = -1
var _last_server_fire_time_ms: int = -1
var _shoot_audio_player: AudioStreamPlayer3D
var _impact_audio_player: AudioStreamPlayer3D


func _ready() -> void:
	avatar = get_parent() as Avatar
	inventory = get_node_or_null(inventory_path) as Inventory
	combat = get_node_or_null(combat_path) as CharacterCombat
	movement_body = get_node_or_null(movement_body_path) as CharacterBody3D
	skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	right_hand_anchor = get_node_or_null(right_hand_path) as BoneAttachment3D
	aim_target = get_node_or_null(aim_target_path) as Node3D
	if aim_target == null and avatar != null:
		aim_target = Node3D.new()
		aim_target.name = "WeaponAimTarget"
		avatar.add_child(aim_target)
	_setup_feedback_nodes()
	_setup_beretta_instance()
	_update_visual_equipped_state()


func _process(_delta: float) -> void:
	_update_aim_target_position()
	_update_hand_attachment_override()
	_update_visual_equipped_state()


func get_equipped_item_id() -> String:
	return String(_equipped_item_id)


func is_aiming() -> bool:
	return _is_aiming


func get_aim_target_position() -> Vector3:
	if aim_target != null:
		return aim_target.global_position
	var from_position: Vector3 = _resolve_fire_origin()
	var direction: Vector3 = _resolve_fire_direction()
	return from_position + direction.normalized() * maxf(max_shoot_distance, 1.0)


func is_gun_equipped() -> bool:
	return _equipped_item_id == ITEM_ID_BERETTA


func equip_item(item_id: StringName) -> bool:
	if inventory == null:
		return false
	if String(item_id).strip_edges().is_empty():
		return false
	if not inventory.has_item(String(item_id), 1):
		return false
	_equipped_item_id = item_id
	_update_visual_equipped_state()
	return true


func unequip_current() -> void:
	_equipped_item_id = &""
	_is_aiming = false
	_update_visual_equipped_state()


func try_buy_beretta(price: int) -> bool:
	if avatar == null:
		return false
	if not avatar.multiplayer.is_server() and not avatar._is_local_controlled():
		return false
	if inventory == null:
		return false
	var metadata: Dictionary = {
		"equippable": true,
		"weapon_type": "beretta"
	}
	return inventory.try_buy_item(String(ITEM_ID_BERETTA), price, 1, metadata)


func try_drop_beretta() -> bool:
	if avatar == null:
		return false
	if not avatar.multiplayer.is_server() and not avatar._is_local_controlled():
		return false
	if inventory == null:
		return false
	var dropped: bool = inventory.try_drop_item(String(ITEM_ID_BERETTA), 1)
	if dropped and _equipped_item_id == ITEM_ID_BERETTA:
		unequip_current()
	return dropped


func set_aiming(aiming: bool) -> void:
	if not is_gun_equipped():
		_is_aiming = false
		return
	_is_aiming = aiming


func apply_network_equipped(item_id: StringName) -> void:
	_equipped_item_id = item_id
	if _equipped_item_id == &"":
		_is_aiming = false
	_update_visual_equipped_state()


func apply_network_aiming(aiming: bool) -> void:
	if not is_gun_equipped():
		_is_aiming = false
		return
	_is_aiming = aiming


func apply_network_aim_target(position: Vector3) -> void:
	_network_aim_target_position = position
	if avatar == null:
		return
	if aim_target != null and not avatar._is_local_controlled():
		aim_target.global_position = position


func request_fire_once() -> void:
	if avatar == null:
		return
	if not avatar._is_local_controlled():
		return
	if not is_gun_equipped():
		return
	if combat != null and not combat.can_act():
		return
	var now_ms: int = Time.get_ticks_msec()
	var fire_interval_ms: int = int((1.0 / maxf(fire_rate_per_second, 0.01)) * 1000.0)
	if _last_local_fire_request_time_ms >= 0 and now_ms - _last_local_fire_request_time_ms < fire_interval_ms:
		return
	_last_local_fire_request_time_ms = now_ms

	var ray_origin: Vector3 = _resolve_fire_origin()
	var ray_direction: Vector3 = _resolve_fire_direction()
	if ray_direction.length_squared() <= 0.0:
		return

	if multiplayer.is_server():
		_server_fire_hitscan(ray_origin, ray_direction)
		return

	var host_id: int = avatar._resolve_host_peer_id()
	if host_id <= 0:
		return
	if not avatar._is_connected_peer(host_id):
		return
	_rpc_request_fire.rpc_id(host_id, ray_origin, ray_direction)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_fire(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != avatar.player_id:
		return
	_server_fire_hitscan(ray_origin, ray_direction)


func _server_fire_hitscan(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if avatar == null:
		return
	if not is_gun_equipped():
		return
	if combat != null and not combat.can_act():
		return

	var now_ms: int = Time.get_ticks_msec()
	var fire_interval_ms: int = int((1.0 / maxf(fire_rate_per_second, 0.01)) * 1000.0)
	if _last_server_fire_time_ms >= 0 and now_ms - _last_server_fire_time_ms < fire_interval_ms:
		return
	_last_server_fire_time_ms = now_ms

	var from_position: Vector3 = ray_origin
	var direction: Vector3 = ray_direction.normalized()
	var to_position: Vector3 = from_position + direction * maxf(max_shoot_distance, 1.0)
	var muzzle_position: Vector3 = from_position
	if right_hand_anchor != null:
		muzzle_position = right_hand_anchor.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false
	var exclude_nodes: Array[RID] = []
	if movement_body != null:
		exclude_nodes.append(movement_body.get_rid())
	query.exclude = exclude_nodes
	var world_3d: World3D = avatar.get_world_3d() if avatar != null else null
	if world_3d == null:
		return
	var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		_broadcast_shot_feedback(muzzle_position, false, to_position, Vector3.UP)
		return
	var hit_position_value: Variant = result.get("position", to_position)
	var hit_position: Vector3 = to_position
	if typeof(hit_position_value) == TYPE_VECTOR3:
		hit_position = hit_position_value as Vector3
	var hit_normal_value: Variant = result.get("normal", Vector3.UP)
	var hit_normal: Vector3 = Vector3.UP
	if typeof(hit_normal_value) == TYPE_VECTOR3:
		hit_normal = hit_normal_value as Vector3
	_broadcast_shot_feedback(muzzle_position, true, hit_position, hit_normal)
	var collider_variant: Variant = result.get("collider", null)
	if collider_variant == null:
		return
	if not (collider_variant is Node):
		return
	var collider_node: Node = collider_variant as Node
	var target_damageable: Node = _resolve_damageable_from_node(collider_node)
	if target_damageable == null:
		return
	if target_damageable == avatar:
		return
	if target_damageable.has_method("can_receive_damage"):
		var can_receive: Variant = target_damageable.call("can_receive_damage")
		if typeof(can_receive) == TYPE_BOOL and not bool(can_receive):
			return
	var applied_result: Variant = target_damageable.call("apply_damage", fire_damage)
	if typeof(applied_result) != TYPE_INT:
		return
	var applied_damage: int = int(applied_result)
	if applied_damage <= 0:
		return
	if target_damageable is Avatar:
		var hit_avatar: Avatar = target_damageable as Avatar
		if hit_avatar.combat != null:
			hit_avatar._send_health_sync_to_owner(hit_avatar.combat.hp, hit_avatar.combat.max_hp)


func _setup_feedback_nodes() -> void:
	_shoot_audio_player = AudioStreamPlayer3D.new()
	_shoot_audio_player.name = "GunShootAudio"
	_shoot_audio_player.max_db = gun_feedback_volume_db
	add_child(_shoot_audio_player)

	_impact_audio_player = AudioStreamPlayer3D.new()
	_impact_audio_player.name = "GunImpactAudio"
	_impact_audio_player.max_db = gun_feedback_volume_db
	add_child(_impact_audio_player)


func _broadcast_shot_feedback(muzzle_position: Vector3, has_hit: bool, hit_position: Vector3, hit_normal: Vector3) -> void:
	_play_shot_feedback_local(muzzle_position, has_hit, hit_position, hit_normal)
	_rpc_play_shot_feedback.rpc(muzzle_position, has_hit, hit_position, hit_normal)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_play_shot_feedback(muzzle_position: Vector3, has_hit: bool, hit_position: Vector3, hit_normal: Vector3) -> void:
	if multiplayer.is_server():
		return
	if avatar == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var host_id: int = avatar._resolve_host_peer_id()
	if sender_id != host_id:
		return
	_play_shot_feedback_local(muzzle_position, has_hit, hit_position, hit_normal)


func _play_shot_feedback_local(muzzle_position: Vector3, has_hit: bool, hit_position: Vector3, hit_normal: Vector3) -> void:
	if _shoot_audio_player != null and gun_shoot_sfx != null:
		if _shoot_audio_player.playing:
			_shoot_audio_player.stop()
		_shoot_audio_player.stream = gun_shoot_sfx
		_shoot_audio_player.global_position = muzzle_position
		_shoot_audio_player.play()

	if not has_hit:
		return

	if _impact_audio_player != null and gun_impact_sfx != null:
		if _impact_audio_player.playing:
			_impact_audio_player.stop()
		_impact_audio_player.stream = gun_impact_sfx
		_impact_audio_player.global_position = hit_position
		_impact_audio_player.play()

	if gun_hit_vfx_scene == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var vfx_instance: Node = gun_hit_vfx_scene.instantiate()
	if vfx_instance == null:
		return
	current_scene.add_child(vfx_instance)
	if vfx_instance is Node3D:
		var vfx_node_3d: Node3D = vfx_instance as Node3D
		vfx_node_3d.global_position = hit_position
		var normal: Vector3 = hit_normal.normalized()
		if normal.length_squared() <= 0.0:
			normal = Vector3.UP
		var up_axis: Vector3 = Vector3.UP
		if absf(normal.dot(up_axis)) > 0.98:
			up_axis = Vector3.FORWARD
		vfx_node_3d.look_at(hit_position + normal, up_axis, true)


func _resolve_damageable_from_node(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("get_damageable_id") and current.has_method("apply_damage"):
			return current
		current = current.get_parent()
	return null


func _setup_beretta_instance() -> void:
	if right_hand_anchor == null:
		return
	if beretta_scene == null:
		return
	var instance_root: Node = beretta_scene.instantiate()
	if instance_root == null:
		return
	if instance_root is Node3D:
		beretta_instance = instance_root as Node3D
	else:
		return
	beretta_instance.name = "BerettaEquipped"
	right_hand_anchor.add_child(beretta_instance)
	beretta_instance.position = beretta_local_position
	beretta_instance.rotation_degrees = beretta_local_rotation_degrees
	beretta_instance.scale = beretta_local_scale
	beretta_instance.visible = false


func _update_visual_equipped_state() -> void:
	if beretta_instance != null:
		beretta_instance.visible = is_gun_equipped()
	if not is_gun_equipped():
		_is_aiming = false


func _update_aim_target_position() -> void:
	if aim_target == null:
		return
	if not _is_aiming:
		return
	if not is_gun_equipped():
		return
	if avatar == null:
		return
	if avatar._is_local_controlled():
		var from_position: Vector3 = _resolve_fire_origin()
		var direction: Vector3 = _resolve_fire_direction()
		if direction.length_squared() <= 0.0:
			return
		aim_target.global_position = from_position + direction.normalized() * maxf(max_shoot_distance, 1.0)
		return
	aim_target.global_position = _network_aim_target_position


func _update_hand_attachment_override() -> void:
	if right_hand_anchor == null:
		return
	if avatar == null:
		return
	var should_override: bool = _is_aiming and is_gun_equipped()
	right_hand_anchor.override_pose = should_override
	if not should_override:
		return

	var target_world: Vector3 = aim_target.global_position if aim_target != null else _network_aim_target_position
	var movement_reference: Node3D = movement_body
	if movement_reference == null:
		movement_reference = avatar
	if movement_reference == null:
		return
	var player_anchor: Vector3 = movement_reference.global_position + Vector3.UP * hand_override_vertical_offset
	var to_target: Vector3 = target_world - player_anchor
	if to_target.length_squared() <= 0.0:
		return
	var target_forward: Vector3 = to_target.normalized()
	var target_right: Vector3 = Vector3.UP.cross(target_forward).normalized()
	if target_right.length_squared() <= 0.0:
		target_right = movement_reference.global_transform.basis.x.normalized()
	var hand_world: Vector3 = player_anchor
	hand_world += target_forward * hand_override_forward_distance
	hand_world += target_right * hand_override_right_offset
	var hand_basis: Basis = Basis.looking_at((target_world - hand_world).normalized(), Vector3.UP)
	var offset_radians: Vector3 = Vector3(
		deg_to_rad(hand_override_look_offset_degrees.x),
		deg_to_rad(hand_override_look_offset_degrees.y),
		deg_to_rad(hand_override_look_offset_degrees.z)
	)
	hand_basis = (hand_basis * Basis.from_euler(offset_radians)).orthonormalized()
	var target_global: Transform3D = Transform3D(hand_basis, hand_world)
	if skeleton != null:
		var target_local: Transform3D = skeleton.global_transform.affine_inverse() * target_global
		target_local.basis = target_local.basis.orthonormalized()
		right_hand_anchor.transform = target_local
		return
	right_hand_anchor.global_transform = target_global


func _resolve_fire_origin() -> Vector3:
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d()
	if camera != null:
		var center: Vector2 = viewport.get_visible_rect().size * 0.5
		return camera.project_ray_origin(center)
	if right_hand_anchor != null:
		return right_hand_anchor.global_position
	if movement_body != null:
		return movement_body.global_position + Vector3.UP * 1.3
	if avatar != null:
		return avatar.global_position + Vector3.UP * 1.3
	return Vector3.ZERO


func _resolve_fire_direction() -> Vector3:
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d()
	if camera != null:
		var center: Vector2 = viewport.get_visible_rect().size * 0.5
		return camera.project_ray_normal(center).normalized()
	if avatar != null:
		var forward: Vector3 = -avatar.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0:
			return forward.normalized()
	if right_hand_anchor != null:
		var hand_forward: Vector3 = -right_hand_anchor.global_transform.basis.z
		if hand_forward.length_squared() > 0.0:
			return hand_forward.normalized()
	return Vector3.FORWARD
