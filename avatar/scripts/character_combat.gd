class_name CharacterCombat
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal state_changed(previous_state: int, new_state: int)
signal damaged(amount: int, current_hp: int)
signal healed(amount: int, current_hp: int)
signal died
signal revived

enum CombatState {
	READY,
	QUICK_MELEE,
	HEAVY_MELEE,
	PARRYING,
	STUNNED,
	DEAD
}

@export var max_hp: int = 100
@export var hp: int = 100
@export var quick_melee_duration: float = 0.2
@export var heavy_melee_duration: float = 0.45
@export var parry_duration: float = 0.35
@export var parry_cooldown: float = 0.6
@export var default_stun_duration: float = 1.0
@export var debug_auto_revive_enabled: bool = true
@export var debug_auto_revive_delay: float = 1.0
@export var debug_auto_revive_hp: int = 100

var state: int = CombatState.READY
var _state_token: int = 0
var _next_parry_time_ms: int = 0


func _ready() -> void:
	# Always start from READY unless hp is truly zero.
	state = CombatState.READY
	max_hp = maxi(1, max_hp)
	hp = clampi(hp, 0, max_hp)
	if hp <= 0:
		_set_state(CombatState.DEAD)
	hp_changed.emit(hp, max_hp)


func can_act() -> bool:
	return state != CombatState.STUNNED and state != CombatState.DEAD


func is_dead() -> bool:
	return state == CombatState.DEAD


func start_quick_melee() -> bool:
	if not _can_start_action():
		return false
	_set_state(CombatState.QUICK_MELEE)
	return true


func start_heavy_melee() -> bool:
	if not _can_start_action():
		return false
	_set_state(CombatState.HEAVY_MELEE)
	return true


func start_punch() -> bool:
	return start_quick_melee()


func is_melee_state() -> bool:
	return state == CombatState.QUICK_MELEE or state == CombatState.HEAVY_MELEE


func start_parry() -> bool:
	if not _can_start_action():
		return false
	if not can_start_parry():
		return false

	var now_ms := Time.get_ticks_msec()
	_next_parry_time_ms = now_ms + int(maxf(parry_cooldown, 0.0) * 1000.0)
	_set_state(CombatState.PARRYING)
	_schedule_state_reset(CombatState.PARRYING, parry_duration, _state_token)
	return true


func stun(duration: float = -1.0) -> bool:
	if state == CombatState.DEAD:
		return false

	var stun_time := default_stun_duration if duration < 0.0 else duration
	_set_state(CombatState.STUNNED)
	_schedule_state_reset(CombatState.STUNNED, stun_time, _state_token)
	return true


func can_start_parry() -> bool:
	if state != CombatState.READY:
		return false
	return Time.get_ticks_msec() >= _next_parry_time_ms


func get_parry_cooldown_remaining() -> float:
	var remaining_ms := _next_parry_time_ms - Time.get_ticks_msec()
	return maxf(float(remaining_ms) / 1000.0, 0.0)


func finish_melee_state(expected_state: int = -1) -> bool:
	if not is_melee_state():
		return false
	if expected_state != -1 and state != expected_state:
		return false
	_set_state(CombatState.READY)
	return true


func apply_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	if state == CombatState.DEAD:
		return 0
	if state == CombatState.PARRYING:
		return 0

	var applied := mini(amount, hp)
	hp = maxi(0, hp - applied)
	damaged.emit(applied, hp)
	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		kill()
	elif is_melee_state():
		stun()

	return applied


func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	if state == CombatState.DEAD:
		return 0

	var previous_hp := hp
	hp = clampi(hp + amount, 0, max_hp)
	var applied := hp - previous_hp
	if applied > 0:
		healed.emit(applied, hp)
		hp_changed.emit(hp, max_hp)
	return applied


func kill() -> void:
	hp = 0
	_set_state(CombatState.DEAD)
	hp_changed.emit(hp, max_hp)
	died.emit()
	_schedule_debug_auto_revive()


func revive(revive_hp: int = -1) -> bool:
	if state != CombatState.DEAD:
		return false

	if revive_hp < 0:
		hp = max_hp
	else:
		hp = clampi(revive_hp, 1, max_hp)

	_set_state(CombatState.READY)
	hp_changed.emit(hp, max_hp)
	revived.emit()
	return true


func _schedule_debug_auto_revive() -> void:
	if not debug_auto_revive_enabled:
		return

	var delay_seconds: float = maxf(debug_auto_revive_delay, 0.01)
	_debug_auto_revive_after_delay(delay_seconds)


func _debug_auto_revive_after_delay(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if is_queued_for_deletion():
		return
	if state != CombatState.DEAD:
		return

	var revive_hp_value: int = debug_auto_revive_hp
	if revive_hp_value <= 0:
		revive()
	else:
		revive(revive_hp_value)


func _can_start_action() -> bool:
	return state == CombatState.READY and hp > 0


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	var previous_state := state
	state = new_state
	_state_token += 1
	state_changed.emit(previous_state, state)


func _schedule_state_reset(expected_state: int, duration: float, token: int) -> void:
	if duration <= 0.0:
		if state == expected_state and state != CombatState.DEAD:
			_set_state(CombatState.READY)
		return
	_reset_state_after_delay(expected_state, duration, token)


func _reset_state_after_delay(expected_state: int, duration: float, token: int) -> void:
	await get_tree().create_timer(duration).timeout
	if is_queued_for_deletion():
		return
	if state == expected_state and _state_token == token and state != CombatState.DEAD:
		_set_state(CombatState.READY)
