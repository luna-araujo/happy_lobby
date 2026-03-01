class_name AvatarAnimations
extends AnimationPlayer

enum State {
	IDLE,
	RUN
}

@export var default_idle_animation: StringName = &"Idle"
@export var run_animation: StringName = &"Run"
@export var movement_body_path: NodePath = NodePath("../Armature")
@export var combat_path: NodePath = NodePath("../CharacterCombat")
@export var run_speed_threshold: float = 0.1
@export var punch_animation: StringName = &"Punch"
@export var parry_animation: StringName = &"Parry"
@export var stunned_animation: StringName = &"Stunned"
@export var dead_animation: StringName = &"Dead"

var movement_body: AvatarMovement
var combat: CharacterCombat
var state: int = -1
var _combat_animation_locked: bool = false

func play_once(animation_name: StringName) -> void:
	if not has_animation(animation_name):
		return

	play(animation_name)
	await animation_finished

	if has_animation(default_idle_animation):
		play(default_idle_animation)
	elif has_animation(&"idle"):
		play(&"idle")


func _ready() -> void:
	movement_body = get_node_or_null(movement_body_path) as AvatarMovement
	if movement_body:
		if not movement_body.movement_updated.is_connected(_on_movement_updated):
			movement_body.movement_updated.connect(_on_movement_updated)
		_on_movement_updated(movement_body.get_horizontal_speed())
	else:
		printerr("AvatarAnimations: AvatarMovement not found at path: %s" % movement_body_path)

	combat = get_node_or_null(combat_path) as CharacterCombat
	if combat:
		if not combat.state_changed.is_connected(_on_combat_state_changed):
			combat.state_changed.connect(_on_combat_state_changed)
		_on_combat_state_changed(combat.state, combat.state)
	else:
		printerr("AvatarAnimations: CharacterCombat not found at path: %s" % combat_path)


func _on_movement_updated(horizontal_speed: float) -> void:
	if _combat_animation_locked:
		return
	var target_state := State.RUN if horizontal_speed > run_speed_threshold else State.IDLE
	_transition_to(target_state)


func _on_combat_state_changed(_previous_state: int, new_state: int) -> void:
	match new_state:
		CharacterCombat.CombatState.READY:
			_combat_animation_locked = false
			if movement_body:
				_on_movement_updated(movement_body.get_horizontal_speed())
			else:
				_transition_to(State.IDLE)
		CharacterCombat.CombatState.PUNCHING:
			_combat_animation_locked = true
			_play_state_animation(punch_animation, &"punch")
		CharacterCombat.CombatState.PARRYING:
			_combat_animation_locked = true
			_play_state_animation(parry_animation, &"parry")
		CharacterCombat.CombatState.STUNNED:
			_combat_animation_locked = true
			_play_state_animation(stunned_animation, &"stunned")
		CharacterCombat.CombatState.DEAD:
			_combat_animation_locked = true
			_play_state_animation(dead_animation, &"dead")


func _transition_to(next_state: int) -> void:
	if state == next_state:
		return

	state = next_state
	match state:
		State.IDLE:
			_play_state_animation(default_idle_animation, &"idle")
		State.RUN:
			_play_state_animation(run_animation, &"run")


func _play_state_animation(preferred_name: StringName, fallback_name: StringName) -> void:
	var animation_name := StringName()
	if has_animation(preferred_name):
		animation_name = preferred_name
	elif has_animation(fallback_name):
		animation_name = fallback_name
	else:
		return

	if current_animation != animation_name:
		play(animation_name)
