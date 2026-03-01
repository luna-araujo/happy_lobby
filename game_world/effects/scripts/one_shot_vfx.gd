class_name OneShotVfx
extends Node3D

@export var auto_start: bool = true
@export var auto_free_seconds: float = 1.0
@export var particles_paths: Array[NodePath] = [NodePath("GPUParticles3D")]
@export var audio_paths: Array[NodePath] = []
@export var animation_player_path: NodePath = NodePath("")
@export var animation_name: StringName = &""

var _particle_nodes: Array = []
var _audio_nodes: Array = []
var _animation_player: AnimationPlayer
var _free_timer_started: bool = false


func _ready() -> void:
	_cache_nodes()
	if auto_start:
		play_once()


func play_once() -> void:
	_cache_nodes()
	_play_particles()
	_play_audio()
	_play_animation()
	_start_auto_free_timer()


func stop() -> void:
	for node_variant in _particle_nodes:
		if node_variant is GPUParticles3D:
			var gpu_particles: GPUParticles3D = node_variant as GPUParticles3D
			gpu_particles.emitting = false
		elif node_variant is CPUParticles3D:
			var cpu_particles: CPUParticles3D = node_variant as CPUParticles3D
			cpu_particles.emitting = false
	for node_variant in _audio_nodes:
		if node_variant is AudioStreamPlayer3D:
			var audio_3d: AudioStreamPlayer3D = node_variant as AudioStreamPlayer3D
			audio_3d.stop()
		elif node_variant is AudioStreamPlayer2D:
			var audio_2d: AudioStreamPlayer2D = node_variant as AudioStreamPlayer2D
			audio_2d.stop()
		elif node_variant is AudioStreamPlayer:
			var audio: AudioStreamPlayer = node_variant as AudioStreamPlayer
			audio.stop()


func _cache_nodes() -> void:
	_particle_nodes.clear()
	_audio_nodes.clear()

	for path_value in particles_paths:
		if path_value == NodePath(""):
			continue
		var particle_node: Node = get_node_or_null(path_value)
		if particle_node != null:
			_particle_nodes.append(particle_node)

	for path_value in audio_paths:
		if path_value == NodePath(""):
			continue
		var audio_node: Node = get_node_or_null(path_value)
		if audio_node != null:
			_audio_nodes.append(audio_node)

	if animation_player_path != NodePath(""):
		_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	else:
		_animation_player = null


func _play_particles() -> void:
	for node_variant in _particle_nodes:
		if node_variant is GPUParticles3D:
			var gpu_particles: GPUParticles3D = node_variant as GPUParticles3D
			gpu_particles.restart()
			gpu_particles.emitting = true
		elif node_variant is CPUParticles3D:
			var cpu_particles: CPUParticles3D = node_variant as CPUParticles3D
			cpu_particles.restart()
			cpu_particles.emitting = true


func _play_audio() -> void:
	for node_variant in _audio_nodes:
		if node_variant is AudioStreamPlayer3D:
			var audio_3d: AudioStreamPlayer3D = node_variant as AudioStreamPlayer3D
			audio_3d.play()
		elif node_variant is AudioStreamPlayer2D:
			var audio_2d: AudioStreamPlayer2D = node_variant as AudioStreamPlayer2D
			audio_2d.play()
		elif node_variant is AudioStreamPlayer:
			var audio: AudioStreamPlayer = node_variant as AudioStreamPlayer
			audio.play()


func _play_animation() -> void:
	if _animation_player == null:
		return
	if animation_name == &"":
		return
	if not _animation_player.has_animation(animation_name):
		return
	_animation_player.play(animation_name)


func _start_auto_free_timer() -> void:
	if _free_timer_started:
		return
	if auto_free_seconds <= 0.0:
		return
	_free_timer_started = true
	_destroy_after_delay(maxf(auto_free_seconds, 0.1))


func _destroy_after_delay(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if is_queued_for_deletion():
		return
	queue_free()
