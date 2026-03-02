extends Area3D

signal interaction_started(peer_id: int, action_id: StringName)

enum ExecutionMode {
	LOCAL_ONLY,
	SERVER_ONLY,
	LOCAL_AND_SERVER
}

@export var enabled: bool = true
@export var prompt_text: String = "Interact"
@export var action_id: StringName = &"interact"
@export var interaction_distance: float = 2.5
@export var interaction_priority: int = 0
@export var execution_mode: ExecutionMode = ExecutionMode.LOCAL_ONLY
@export var interaction_origin_path: NodePath


func _ready() -> void:
	add_to_group("InteractionArea")


func can_interact(interactor: Node) -> bool:
	if not enabled:
		return false
	if interactor == null:
		return false
	var interactor_avatar: Avatar = interactor.get("avatar") as Avatar
	if interactor_avatar == null:
		return false
	var interactor_distance: float = 2.5
	var interactor_distance_variant: Variant = interactor.get("max_interaction_distance")
	if typeof(interactor_distance_variant) == TYPE_FLOAT or typeof(interactor_distance_variant) == TYPE_INT:
		interactor_distance = float(interactor_distance_variant)
	return _is_avatar_within_distance(
		interactor_avatar,
		resolve_interaction_distance(interactor_distance)
	)


func can_interact_server(interactor_avatar: Avatar, interactor_peer_id: int) -> bool:
	if not enabled:
		return false
	if interactor_peer_id <= 0:
		return false
	if interactor_avatar == null:
		return false
	return _is_avatar_within_distance(interactor_avatar, resolve_interaction_distance(interaction_distance))


func resolve_interaction_distance(default_distance: float) -> float:
	var resolved_distance: float = interaction_distance
	if resolved_distance <= 0.0:
		resolved_distance = default_distance
	return maxf(resolved_distance, 0.1)


func get_prompt_text(_interactor: Node) -> String:
	return prompt_text.strip_edges()


func get_action_id(_interactor: Node) -> StringName:
	return action_id


func get_target_position(_interactor: Node) -> Vector3:
	var origin_node: Node3D = _resolve_interaction_origin_node()
	if origin_node != null:
		return origin_node.global_position
	return global_position


func interact_local(_interactor: Node, _resolved_action_id: StringName) -> void:
	pass


func interact_server(interactor_peer_id: int, requested_action_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	if interactor_peer_id <= 0:
		return
	var expected_action_id: StringName = get_action_id(null)
	if expected_action_id != &"" and requested_action_id != expected_action_id:
		return
	interaction_started.emit(interactor_peer_id, requested_action_id)


func _resolve_interaction_origin_node() -> Node3D:
	if not interaction_origin_path.is_empty():
		var configured_origin: Node3D = get_node_or_null(interaction_origin_path) as Node3D
		if configured_origin != null:
			return configured_origin
	var parent_node_3d: Node3D = get_parent() as Node3D
	if parent_node_3d != null:
		return parent_node_3d
	return null


func _is_avatar_within_distance(target_avatar: Avatar, max_distance: float) -> bool:
	if target_avatar == null:
		return false
	var avatar_position: Vector3 = _resolve_avatar_interaction_position(target_avatar)
	return avatar_position.distance_to(get_target_position(null)) <= maxf(max_distance, 0.1)


func _resolve_avatar_interaction_position(target_avatar: Avatar) -> Vector3:
	if target_avatar == null:
		return Vector3.ZERO
	if target_avatar.movement_body != null and is_instance_valid(target_avatar.movement_body):
		return target_avatar.movement_body.global_position
	return target_avatar.global_position
