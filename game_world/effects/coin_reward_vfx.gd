class_name CoinRewardVfx
extends Node3D

@export var flight_duration: float = 0.55
@export var arc_height: float = 1.2
@export var initial_height_offset: float = 0.8

var target_player_id: int = 0
var reward_amount: int = 0
var _flight_start_position: Vector3 = Vector3.ZERO
var _flight_tween: Tween
var _audio_player: AudioStreamPlayer3D
var _coin_visual_root: Node3D


func _ready() -> void:
	_audio_player = get_node_or_null("CoinAudio") as AudioStreamPlayer3D
	_coin_visual_root = get_node_or_null("CoinModel") as Node3D
	if _audio_player != null and _audio_player.stream == null:
		_audio_player.stream = _build_coin_sound_stream()
	if _coin_visual_root != null:
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
	if _audio_player != null and _audio_player.stream != null:
		_audio_player.play()
		await _audio_player.finished
	queue_free()


func _resolve_target_position() -> Vector3:
	var target_avatar: Avatar = _find_avatar_by_player_id(target_player_id)
	if target_avatar != null:
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


func _build_coin_sound_stream() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var length_seconds: float = 0.16
	var sample_count: int = int(length_seconds * float(sample_rate))
	var pcm_data: PackedByteArray = PackedByteArray()
	pcm_data.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var t: float = float(sample_index) / float(sample_rate)
		var envelope: float = exp(-18.0 * t)
		var tone_a: float = sin(TAU * 1800.0 * t)
		var tone_b: float = sin(TAU * 2600.0 * t) * 0.5
		var mixed: float = (tone_a + tone_b) * 0.5 * envelope
		var sample_value: int = int(clampf(mixed, -1.0, 1.0) * 32767.0)
		pcm_data[sample_index * 2] = sample_value & 0xFF
		pcm_data[(sample_index * 2) + 1] = (sample_value >> 8) & 0xFF

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm_data
	return stream
