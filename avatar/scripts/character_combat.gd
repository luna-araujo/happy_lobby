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
	PUNCHING,
	PARRYING,
	STUNNED,
	DEAD
}

@export var max_hp: int = 100
@export var hp: int = 100
@export var punch_duration: float = 0.25
@export var parry_duration: float = 0.35
@export var default_stun_duration: float = 1.0

var state: int = CombatState.READY
var _state_token: int = 0


func _ready() -> void:
	max_hp = maxi(1, max_hp)
	hp = clampi(hp, 0, max_hp)
	if hp <= 0:
		_set_state(CombatState.DEAD)
	hp_changed.emit(hp, max_hp)


func can_act() -> bool:
	return state != CombatState.STUNNED and state != CombatState.DEAD


func is_dead() -> bool:
	return state == CombatState.DEAD


func start_punch() -> bool:
	if not _can_start_action():
		return false
	_set_state(CombatState.PUNCHING)
	_schedule_state_reset(CombatState.PUNCHING, punch_duration, _state_token)
	return true


func start_parry() -> bool:
	if not _can_start_action():
		return false
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
	elif state == CombatState.PUNCHING:
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
