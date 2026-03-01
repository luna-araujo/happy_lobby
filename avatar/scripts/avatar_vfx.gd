class_name AvatarVfx
extends Node3D

@export var avatar_path: NodePath = NodePath("..")
@export var left_hand_path: NodePath = NodePath("../Armature/Skeleton3D/LHand")
@export var right_hand_path: NodePath = NodePath("../Armature/Skeleton3D/RHand")
@export var center_anchor_path: NodePath = NodePath("../Armature")
@export var vfx_auto_free_seconds: float = 1.6
@export var oneshot_pool_size: int = 8
@export var enable_remote_audio: bool = true
@export var run_loop_volume_db: float = -12.0
@export var oneshot_volume_db: float = -5.0
@export var run_loop_pitch_scale: float = 1.0

@export var run_loop_sfx: AudioStream
@export var light_melee_whoosh_sfx: AudioStream
@export var heavy_melee_whoosh_sfx: AudioStream
@export var light_melee_hit_sfx: AudioStream
@export var heavy_melee_hit_sfx: AudioStream
@export var parry_sfx: AudioStream
@export var stun_sfx: AudioStream
@export var damaged_sfx: AudioStream
@export var death_sfx: AudioStream
@export var revive_sfx: AudioStream

@export var light_melee_swing_vfx: PackedScene
@export var heavy_melee_swing_vfx: PackedScene
@export var light_melee_hit_vfx: PackedScene
@export var heavy_melee_hit_vfx: PackedScene
@export var parry_vfx: PackedScene
@export var stun_vfx: PackedScene
@export var damage_vfx: PackedScene
@export var death_vfx: PackedScene
@export var revive_vfx: PackedScene

var avatar: Avatar
var _left_hand_anchor: Node3D
var _right_hand_anchor: Node3D
var _center_anchor: Node3D
var _run_loop_player: AudioStreamPlayer3D
var _oneshot_players: Array[AudioStreamPlayer3D] = []
var _oneshot_player_index: int = 0


func _ready() -> void:
	avatar = get_node_or_null(avatar_path) as Avatar
	_left_hand_anchor = get_node_or_null(left_hand_path) as Node3D
	_right_hand_anchor = get_node_or_null(right_hand_path) as Node3D
	_center_anchor = get_node_or_null(center_anchor_path) as Node3D
	if _center_anchor == null:
		_center_anchor = get_parent() as Node3D
	_setup_audio_players()
	_connect_avatar_signals()


func _setup_audio_players() -> void:
	_run_loop_player = AudioStreamPlayer3D.new()
	_run_loop_player.name = "RunLoopPlayer"
	_run_loop_player.max_db = run_loop_volume_db
	_run_loop_player.pitch_scale = run_loop_pitch_scale
	_run_loop_player.stream = run_loop_sfx
	add_child(_run_loop_player)

	var pool_count: int = maxi(oneshot_pool_size, 1)
	for pool_index in range(pool_count):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "OneShot_%d" % pool_index
		player.max_db = oneshot_volume_db
		add_child(player)
		_oneshot_players.append(player)


func _connect_avatar_signals() -> void:
	if avatar == null:
		return
	if not avatar.light_melee_started.is_connected(_on_light_melee_started):
		avatar.light_melee_started.connect(_on_light_melee_started)
	if not avatar.heavy_melee_started.is_connected(_on_heavy_melee_started):
		avatar.heavy_melee_started.connect(_on_heavy_melee_started)
	if not avatar.light_melee_hit.is_connected(_on_light_melee_hit):
		avatar.light_melee_hit.connect(_on_light_melee_hit)
	if not avatar.heavy_melee_hit.is_connected(_on_heavy_melee_hit):
		avatar.heavy_melee_hit.connect(_on_heavy_melee_hit)
	if not avatar.run_started.is_connected(_on_run_started):
		avatar.run_started.connect(_on_run_started)
	if not avatar.run_stopped.is_connected(_on_run_stopped):
		avatar.run_stopped.connect(_on_run_stopped)
	if not avatar.parry_started.is_connected(_on_parry_started):
		avatar.parry_started.connect(_on_parry_started)
	if not avatar.parry_ended.is_connected(_on_parry_ended):
		avatar.parry_ended.connect(_on_parry_ended)
	if not avatar.stun_started.is_connected(_on_stun_started):
		avatar.stun_started.connect(_on_stun_started)
	if not avatar.stun_ended.is_connected(_on_stun_ended):
		avatar.stun_ended.connect(_on_stun_ended)
	if not avatar.damaged.is_connected(_on_damaged):
		avatar.damaged.connect(_on_damaged)
	if not avatar.died.is_connected(_on_died):
		avatar.died.connect(_on_died)
	if not avatar.revived.is_connected(_on_revived):
		avatar.revived.connect(_on_revived)


func _on_light_melee_started() -> void:
	_play_one_shot(light_melee_whoosh_sfx, _anchor_position(_right_hand_anchor))
	_spawn_vfx(light_melee_swing_vfx, _anchor_position(_right_hand_anchor))


func _on_heavy_melee_started() -> void:
	_play_one_shot(heavy_melee_whoosh_sfx, _anchor_position(_left_hand_anchor))
	_spawn_vfx(heavy_melee_swing_vfx, _anchor_position(_left_hand_anchor))


func _on_light_melee_hit(target_damageable_id: int, _damage: int) -> void:
	var hit_position: Vector3 = _resolve_damageable_position(target_damageable_id)
	_play_one_shot(light_melee_hit_sfx, hit_position)
	_spawn_vfx(light_melee_hit_vfx, hit_position)


func _on_heavy_melee_hit(target_damageable_id: int, _damage: int) -> void:
	var hit_position: Vector3 = _resolve_damageable_position(target_damageable_id)
	_play_one_shot(heavy_melee_hit_sfx, hit_position)
	_spawn_vfx(heavy_melee_hit_vfx, hit_position)


func _on_run_started(_speed: float) -> void:
	if not _can_play_audio():
		return
	if _run_loop_player == null:
		return
	if run_loop_sfx == null:
		return
	_run_loop_player.stream = run_loop_sfx
	if _center_anchor != null:
		_run_loop_player.global_position = _center_anchor.global_position
	if not _run_loop_player.playing:
		_run_loop_player.play()


func _on_run_stopped() -> void:
	if _run_loop_player == null:
		return
	if _run_loop_player.playing:
		_run_loop_player.stop()


func _on_parry_started() -> void:
	var center_position: Vector3 = _anchor_position(_center_anchor)
	_play_one_shot(parry_sfx, center_position)
	_spawn_vfx(parry_vfx, center_position)


func _on_parry_ended() -> void:
	pass


func _on_stun_started() -> void:
	var center_position: Vector3 = _anchor_position(_center_anchor)
	_play_one_shot(stun_sfx, center_position)
	_spawn_vfx(stun_vfx, center_position)
	_on_run_stopped()


func _on_stun_ended() -> void:
	pass


func _on_damaged(_amount: int, _current_hp: int) -> void:
	var center_position: Vector3 = _anchor_position(_center_anchor)
	_play_one_shot(damaged_sfx, center_position)
	_spawn_vfx(damage_vfx, center_position)


func _on_died() -> void:
	var center_position: Vector3 = _anchor_position(_center_anchor)
	_on_run_stopped()
	_play_one_shot(death_sfx, center_position)
	_spawn_vfx(death_vfx, center_position)


func _on_revived() -> void:
	var center_position: Vector3 = _anchor_position(_center_anchor)
	_play_one_shot(revive_sfx, center_position)
	_spawn_vfx(revive_vfx, center_position)


func _play_one_shot(stream: AudioStream, at_position: Vector3) -> void:
	if stream == null:
		return
	if not _can_play_audio():
		return
	if _oneshot_players.is_empty():
		return
	var player: AudioStreamPlayer3D = _oneshot_players[_oneshot_player_index]
	_oneshot_player_index = (_oneshot_player_index + 1) % _oneshot_players.size()
	if player.playing:
		player.stop()
	player.stream = stream
	player.global_position = at_position
	player.play()


func _spawn_vfx(vfx_scene: PackedScene, at_position: Vector3) -> void:
	if vfx_scene == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var vfx_instance: Node = vfx_scene.instantiate()
	current_scene.add_child(vfx_instance)
	if vfx_instance is Node3D:
		var vfx_node_3d: Node3D = vfx_instance as Node3D
		vfx_node_3d.global_position = at_position
	_auto_free_vfx_instance(vfx_instance)


func _auto_free_vfx_instance(vfx_instance: Node) -> void:
	var lifetime: float = maxf(vfx_auto_free_seconds, 0.1)
	_auto_free_vfx_after_delay(vfx_instance, lifetime)


func _auto_free_vfx_after_delay(vfx_instance: Node, delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if not is_instance_valid(vfx_instance):
		return
	if vfx_instance.is_queued_for_deletion():
		return
	vfx_instance.queue_free()


func _resolve_damageable_position(target_damageable_id: int) -> Vector3:
	if target_damageable_id <= 0:
		return _anchor_position(_center_anchor)
	var root_node: Node = get_tree().root
	var stack: Array[Node] = []
	stack.push_back(root_node)
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node.has_method("get_damageable_id"):
			var resolved_id: Variant = node.call("get_damageable_id")
			if typeof(resolved_id) == TYPE_INT and int(resolved_id) == target_damageable_id:
				if node is Avatar:
					var hit_avatar: Avatar = node as Avatar
					if hit_avatar.movement_body != null:
						return hit_avatar.movement_body.global_position + Vector3.UP * 1.2
				if node is Node3D:
					var node_3d: Node3D = node as Node3D
					return node_3d.global_position + Vector3.UP * 0.8
		var children: Array = node.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child as Node)
	return _anchor_position(_center_anchor)


func _anchor_position(anchor: Node3D) -> Vector3:
	if anchor != null:
		return anchor.global_position
	var parent_node_3d: Node3D = get_parent() as Node3D
	if parent_node_3d != null:
		return parent_node_3d.global_position
	return global_position


func _can_play_audio() -> bool:
	if enable_remote_audio:
		return true
	if avatar == null:
		return false
	return avatar._is_local_controlled()
