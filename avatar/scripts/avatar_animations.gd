class_name AvatarAnimations
extends AnimationPlayer

@export var default_idle_animation: StringName = &"idle"
@export var run_animation: StringName = &"run"
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")
@export var movement_body_path: NodePath = NodePath("../Armature")
@export var combat_path: NodePath = NodePath("../CharacterCombat")
@export var run_speed_threshold: float = 0.1
@export var quick_melee_animation: StringName = &"light_melee"
@export var heavy_melee_animation: StringName = &"heavy_melee"
@export var heavy_melee_burst_amount: float = 10.0
@export var parry_animation: StringName = &"parry"
@export var stunned_animation: StringName = &"stun"
@export var dead_animation: StringName = &"dead"

var movement_body: AvatarMovement
var combat: CharacterCombat
var animation_tree: AnimationTree
var state_machine_playback: AnimationNodeStateMachinePlayback
var _pending_melee_state: int = -1
var _pending_melee_tree_state: StringName = &""
var _pending_melee_entered: bool = false
var _pending_melee_started_ms: int = -1
var _heavy_melee_burst_used: bool = false
var _desired_tree_state: StringName = &"Locomotion"
var _tree_state_initialized: bool = false
var _network_locomotion_speed: float = -1.0

const TREE_STATE_LOCOMOTION: StringName = &"Locomotion"
const TREE_STATE_QUICK_MELEE: StringName = &"QuickMelee"
const TREE_STATE_HEAVY_MELEE: StringName = &"HeavyMelee"
const TREE_STATE_PARRY: StringName = &"Parry"
const TREE_STATE_STUN: StringName = &"Stun"
const TREE_STATE_DEAD: StringName = &"Dead"


func play_once(animation_name: StringName) -> void:
	if not has_animation(animation_name):
		return
	if animation_tree:
		animation_tree.active = false
	play(animation_name)
	await animation_finished
	if animation_tree:
		animation_tree.active = true
		if state_machine_playback:
			state_machine_playback.travel(TREE_STATE_LOCOMOTION)


func _ready() -> void:
	movement_body = get_node_or_null(movement_body_path) as AvatarMovement
	if movement_body:
		if not movement_body.movement_updated.is_connected(_on_movement_updated):
			movement_body.movement_updated.connect(_on_movement_updated)
	else:
		printerr("AvatarAnimations: AvatarMovement not found at path: %s" % movement_body_path)

	combat = get_node_or_null(combat_path) as CharacterCombat
	if combat:
		if not combat.state_changed.is_connected(_on_combat_state_changed):
			combat.state_changed.connect(_on_combat_state_changed)
	else:
		printerr("AvatarAnimations: CharacterCombat not found at path: %s" % combat_path)

	_setup_animation_tree()
	_on_movement_updated(movement_body.get_horizontal_speed() if movement_body else 0.0)
	_on_combat_state_changed(-1, combat.state if combat else CharacterCombat.CombatState.READY)


func _process(_delta: float) -> void:
	_sync_tree_state()
	_update_locomotion_blend()
	_complete_pending_melee_if_tree_finished()


func _on_movement_updated(horizontal_speed: float) -> void:
	if not animation_tree:
		return
	_update_locomotion_blend(horizontal_speed)


func _on_combat_state_changed(_previous_state: int, new_state: int) -> void:
	_pending_melee_state = -1
	_pending_melee_tree_state = &""
	_pending_melee_entered = false
	_pending_melee_started_ms = -1
	_heavy_melee_burst_used = false

	match new_state:
		CharacterCombat.CombatState.READY:
			_desired_tree_state = TREE_STATE_LOCOMOTION
			_try_travel(_desired_tree_state)
		CharacterCombat.CombatState.QUICK_MELEE:
			_desired_tree_state = TREE_STATE_QUICK_MELEE
			_set_melee_state(CharacterCombat.CombatState.QUICK_MELEE, TREE_STATE_QUICK_MELEE)
		CharacterCombat.CombatState.HEAVY_MELEE:
			_desired_tree_state = TREE_STATE_HEAVY_MELEE
			_set_melee_state(CharacterCombat.CombatState.HEAVY_MELEE, TREE_STATE_HEAVY_MELEE)
		CharacterCombat.CombatState.PARRYING:
			_desired_tree_state = TREE_STATE_PARRY
			_try_travel(_desired_tree_state)
		CharacterCombat.CombatState.STUNNED:
			_desired_tree_state = TREE_STATE_STUN
			_try_travel(_desired_tree_state)
		CharacterCombat.CombatState.DEAD:
			_desired_tree_state = TREE_STATE_DEAD
			_try_travel(_desired_tree_state)


func trigger_heavy_melee_burst(amount: float = -1.0) -> void:
	if _heavy_melee_burst_used:
		return
	if not combat or combat.state != CharacterCombat.CombatState.HEAVY_MELEE:
		return
	if not movement_body:
		return

	var burst_amount := heavy_melee_burst_amount if amount < 0.0 else amount
	movement_body.apply_heavy_melee_impulse_from_camera(burst_amount)
	_heavy_melee_burst_used = true


func get_current_tree_state_name() -> String:
	if not state_machine_playback:
		return ""
	return String(state_machine_playback.get_current_node())


func get_desired_tree_state_name() -> String:
	return String(_desired_tree_state)


func set_network_tree_state(state_name: StringName) -> void:
	_desired_tree_state = state_name
	_try_travel(state_name)


func set_network_locomotion_speed(horizontal_speed: float) -> void:
	_network_locomotion_speed = maxf(horizontal_speed, 0.0)


func _update_locomotion_blend(horizontal_speed: float = -1.0) -> void:
	if not animation_tree:
		return
	var speed := horizontal_speed
	if speed < 0.0 and _network_locomotion_speed >= 0.0 and movement_body and not movement_body.is_multiplayer_authority():
		speed = _network_locomotion_speed
	if speed < 0.0 and movement_body:
		speed = movement_body.get_horizontal_speed()
	if speed < 0.0:
		speed = 0.0
	var target_speed := maxf(run_speed_threshold, 0.01)
	var blend := clampf(speed / target_speed, 0.0, 1.0)
	animation_tree.set("parameters/%s/blend_position" % String(TREE_STATE_LOCOMOTION), blend)


func _complete_pending_melee_if_tree_finished() -> void:
	if _pending_melee_state == -1:
		return
	if not state_machine_playback:
		return
	if not combat:
		return
	var current_state := StringName(state_machine_playback.get_current_node())
	if current_state == _pending_melee_tree_state:
		_pending_melee_entered = true
		if _is_pending_melee_timed_out():
			_finish_pending_melee()
		return
	if not _pending_melee_entered:
		if _is_pending_melee_timed_out():
			_finish_pending_melee()
		return
	_finish_pending_melee()


func _resolve_animation_name(preferred_name: StringName, fallback_name: StringName) -> StringName:
	var animation_name: StringName = &""
	if has_animation(preferred_name):
		animation_name = preferred_name
	elif has_animation(fallback_name):
		animation_name = fallback_name
	return animation_name


func _set_melee_state(melee_state: int, tree_state: StringName) -> void:
	_pending_melee_state = melee_state
	_pending_melee_tree_state = tree_state
	_pending_melee_entered = false
	_pending_melee_started_ms = Time.get_ticks_msec()
	_desired_tree_state = tree_state
	_try_travel(tree_state)


func _is_pending_melee_timed_out() -> bool:
	if _pending_melee_state == -1:
		return false
	if _pending_melee_started_ms < 0:
		return false

	var elapsed_s := float(Time.get_ticks_msec() - _pending_melee_started_ms) / 1000.0
	var timeout_s := _get_pending_melee_timeout_seconds() + 0.15
	return elapsed_s >= timeout_s


func _get_pending_melee_timeout_seconds() -> float:
	if not combat:
		return 0.5
	if _pending_melee_state == CharacterCombat.CombatState.HEAVY_MELEE:
		return maxf(combat.heavy_melee_duration, 0.05)
	if _pending_melee_state == CharacterCombat.CombatState.QUICK_MELEE:
		return maxf(combat.quick_melee_duration, 0.05)
	return 0.5


func _finish_pending_melee() -> void:
	if not combat:
		return
	if combat.finish_melee_state(_pending_melee_state):
		_pending_melee_state = -1
		_pending_melee_tree_state = &""
		_pending_melee_entered = false
		_pending_melee_started_ms = -1
		_heavy_melee_burst_used = false
		_desired_tree_state = TREE_STATE_LOCOMOTION
		_try_travel(_desired_tree_state)


func _setup_animation_tree() -> void:
	animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
	if not animation_tree:
		animation_tree = AnimationTree.new()
		animation_tree.name = "AnimationTree"
		get_parent().add_child(animation_tree)

	animation_tree.anim_player = animation_tree.get_path_to(self)
	if animation_tree.tree_root == null:
		animation_tree.tree_root = _build_state_machine()
	animation_tree.active = true
	state_machine_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


func _sync_tree_state() -> void:
	if not animation_tree:
		return
	if not state_machine_playback:
		state_machine_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if not state_machine_playback:
		return
	if not _tree_state_initialized:
		_try_travel(_desired_tree_state)
		_tree_state_initialized = true
	else:
		_try_travel(_desired_tree_state)


func _try_travel(state_name: StringName) -> void:
	if not state_machine_playback:
		return
	if StringName(state_machine_playback.get_current_node()) == state_name:
		return
	state_machine_playback.travel(state_name)


func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	locomotion.add_blend_point(_make_anim_node(default_idle_animation, &"idle"), 0.0)
	locomotion.add_blend_point(_make_anim_node(run_animation, &"run"), 1.0)

	machine.add_node(TREE_STATE_LOCOMOTION, locomotion, Vector2(0.0, 0.0))
	machine.add_node(TREE_STATE_QUICK_MELEE, _make_anim_node(quick_melee_animation, &"light_melee"), Vector2(280.0, -180.0))
	machine.add_node(TREE_STATE_HEAVY_MELEE, _make_anim_node(heavy_melee_animation, &"heavy_melee"), Vector2(280.0, 0.0))
	machine.add_node(TREE_STATE_PARRY, _make_anim_node(parry_animation, &"parry"), Vector2(280.0, 180.0))
	machine.add_node(TREE_STATE_STUN, _make_anim_node(stunned_animation, &"stun"), Vector2(560.0, -90.0))
	machine.add_node(TREE_STATE_DEAD, _make_anim_node(dead_animation, &"stun"), Vector2(560.0, 120.0))

	_add_transition(machine, &"Start", TREE_STATE_LOCOMOTION, true)

	_add_transition(machine, TREE_STATE_LOCOMOTION, TREE_STATE_QUICK_MELEE, true)
	_add_transition(machine, TREE_STATE_LOCOMOTION, TREE_STATE_HEAVY_MELEE, true)
	_add_transition(machine, TREE_STATE_LOCOMOTION, TREE_STATE_PARRY, true)
	_add_transition(machine, TREE_STATE_LOCOMOTION, TREE_STATE_STUN, true)
	_add_transition(machine, TREE_STATE_LOCOMOTION, TREE_STATE_DEAD, true)

	_add_transition(machine, TREE_STATE_QUICK_MELEE, TREE_STATE_LOCOMOTION, false)
	_add_transition(machine, TREE_STATE_HEAVY_MELEE, TREE_STATE_LOCOMOTION, false)
	_add_transition(machine, TREE_STATE_PARRY, TREE_STATE_LOCOMOTION, true)
	_add_transition(machine, TREE_STATE_STUN, TREE_STATE_LOCOMOTION, true)
	_add_transition(machine, TREE_STATE_DEAD, TREE_STATE_LOCOMOTION, true)

	return machine


func _add_transition(machine: AnimationNodeStateMachine, from_state: StringName, to_state: StringName, immediate: bool) -> void:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = 0.06
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE if immediate else AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	machine.add_transition(from_state, to_state, transition)


func _make_anim_node(preferred_name: StringName, fallback_name: StringName) -> AnimationNodeAnimation:
	var anim_node := AnimationNodeAnimation.new()
	anim_node.animation = _resolve_animation_name(preferred_name, fallback_name)
	return anim_node
