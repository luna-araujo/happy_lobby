class_name AvatarMeleeController
extends Node

const ATTACK_TYPE_QUICK: int = 0
const ATTACK_TYPE_HEAVY: int = 1

@export var quick_hitbox_path: NodePath = NodePath("../Armature/QuickMeleeHitbox")
@export var heavy_hitbox_path: NodePath = NodePath("../Armature/Skeleton3D/LHand/HeavyMeleeHitbox")
@export var quick_damage: int = 15
@export var heavy_damage: int = 30
@export var quick_fallback_range: float = 3.4
@export var heavy_fallback_range: float = 3.8

var avatar: Avatar
var quick_hitbox: Area3D
var heavy_hitbox: Area3D
var quick_hit_ids: Dictionary = {}
var heavy_hit_ids: Dictionary = {}
var quick_swing_token: int = 0
var heavy_swing_token: int = 0


func _ready() -> void:
	avatar = get_parent() as Avatar
	quick_hitbox = get_node_or_null(quick_hitbox_path) as Area3D
	heavy_hitbox = get_node_or_null(heavy_hitbox_path) as Area3D

	if quick_hitbox:
		quick_hitbox.monitoring = false
	if heavy_hitbox:
		heavy_hitbox.monitoring = false


func _physics_process(_delta: float) -> void:
	_process_active_hitbox(ATTACK_TYPE_QUICK)
	_process_active_hitbox(ATTACK_TYPE_HEAVY)


func begin_quick_swing_window(_duration: float) -> void:
	anim_clear_melee_hit_cache()
	quick_swing_token += 1


func begin_heavy_swing_window(_duration: float) -> void:
	anim_clear_melee_hit_cache()
	heavy_swing_token += 1


func anim_enable_quick_hitbox() -> void:
	if quick_hitbox:
		quick_hitbox.monitoring = true


func anim_disable_quick_hitbox() -> void:
	if quick_hitbox:
		quick_hitbox.monitoring = false


func anim_enable_heavy_hitbox() -> void:
	if heavy_hitbox:
		heavy_hitbox.monitoring = true


func anim_disable_heavy_hitbox() -> void:
	if heavy_hitbox:
		heavy_hitbox.monitoring = false


func anim_clear_melee_hit_cache() -> void:
	quick_hit_ids.clear()
	heavy_hit_ids.clear()


func is_hitbox_active(attack_type: int) -> bool:
	var hitbox: Area3D = _hitbox_for_type(attack_type)
	return hitbox != null and hitbox.monitoring


func can_hit_target(target_avatar: Avatar, attack_type: int) -> bool:
	if target_avatar == null:
		return false
	if avatar == null:
		return false
	if target_avatar == avatar:
		return false
	if not is_hitbox_active(attack_type):
		return false
	if _cache_for_type(attack_type).has(target_avatar.player_id):
		return false

	var hitbox: Area3D = _hitbox_for_type(attack_type)
	if hitbox == null:
		return false

	var overlaps: Array = hitbox.get_overlapping_bodies()
	for body in overlaps:
		var hit_avatar: Avatar = _resolve_avatar_from_node(body)
		if hit_avatar == target_avatar:
			return true

	return false


func mark_target_hit(target_avatar: Avatar, attack_type: int) -> void:
	if target_avatar == null:
		return
	var cache: Dictionary = _cache_for_type(attack_type)
	cache[target_avatar.player_id] = true


func get_current_swing_token(attack_type: int) -> int:
	if attack_type == ATTACK_TYPE_HEAVY:
		return heavy_swing_token
	return quick_swing_token


func is_swing_token_valid_for_active_window(attack_type: int, swing_token: int) -> bool:
	if swing_token <= 0:
		return false
	var current_token: int = get_current_swing_token(attack_type)
	if current_token <= 0:
		return true
	return absi(swing_token - current_token) <= 2


func get_damage_for_attack_type(attack_type: int) -> int:
	if attack_type == ATTACK_TYPE_HEAVY:
		return heavy_damage
	return quick_damage


func _process_active_hitbox(attack_type: int) -> void:
	if avatar == null:
		return
	if not avatar.is_multiplayer_authority():
		return
	if not is_hitbox_active(attack_type):
		return

	var hitbox: Area3D = _hitbox_for_type(attack_type)
	if hitbox == null:
		return

	var overlaps: Array = hitbox.get_overlapping_bodies()
	for body in overlaps:
		var target_avatar: Avatar = _resolve_avatar_from_node(body)
		if target_avatar == null:
			continue
		if target_avatar == avatar:
			continue
		if _cache_for_type(attack_type).has(target_avatar.player_id):
			continue

		var damage_amount: int = get_damage_for_attack_type(attack_type)
		var swing_token: int = get_current_swing_token(attack_type)
		avatar.request_melee_damage(target_avatar, damage_amount, attack_type, swing_token)
		if not avatar.multiplayer.is_server():
			mark_target_hit(target_avatar, attack_type)


func _resolve_avatar_from_node(node: Node) -> Avatar:
	var current: Node = node
	while current != null:
		if current is Avatar:
			return current as Avatar
		current = current.get_parent()
	return null


func _hitbox_for_type(attack_type: int) -> Area3D:
	if attack_type == ATTACK_TYPE_HEAVY:
		return heavy_hitbox
	return quick_hitbox


func _cache_for_type(attack_type: int) -> Dictionary:
	if attack_type == ATTACK_TYPE_HEAVY:
		return heavy_hit_ids
	return quick_hit_ids


func is_target_within_fallback_range(target_avatar: Avatar, attack_type: int) -> bool:
	if avatar == null or target_avatar == null:
		return false

	var source_position: Vector3 = avatar.global_position
	var target_position: Vector3 = target_avatar.global_position
	if avatar.movement_body:
		source_position = avatar.movement_body.global_position
	if target_avatar.movement_body:
		target_position = target_avatar.movement_body.global_position

	var distance: float = source_position.distance_to(target_position)
	var threshold: float = quick_fallback_range
	if attack_type == ATTACK_TYPE_HEAVY:
		threshold = heavy_fallback_range
	return distance <= threshold
