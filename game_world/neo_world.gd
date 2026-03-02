class_name NeoWorld
extends Node3D

const AVATAR_SCENE: PackedScene = preload("res://avatar/scenes/avatar.tscn")
const TEST_NPC_SCENE: PackedScene = preload("res://game_world/npc/test_npc.tscn")
const DROPPED_ITEM_SCENE: PackedScene = preload("res://game_world/dropped_item/dropped_item.tscn")
@export var spawn_area_size: float = 20.0
@export var test_npc_spawn_count_on_server_start: int = 10
@export var test_npc_spawn_area_size: float = 20.0
@export var dropped_item_spread_radius: float = 0.65
@export var dropped_item_arc_duration_min_seconds: float = 0.35
@export var dropped_item_arc_duration_max_seconds: float = 0.55

var _next_test_npc_id: int = 1000000
var _next_dropped_item_id: int = 1


func spawn_player_character(id: int, username: String = "") -> Avatar:
	# Server spawns a new player avatar and notifies clients.
	if not multiplayer.is_server():
		return null

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	player_avatar.player_id = id
	player_avatar.name = "Player_%s" % id
	player_avatar.display_name = username if not username.is_empty() else player_avatar.name
	player_avatar.set_multiplayer_authority(id)
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.position = Vector3(
		randf_range(-spawn_area_size, spawn_area_size),
		0.0,
		randf_range(-spawn_area_size, spawn_area_size)
	)

	_spawn_player_on_clients.rpc(id, player_avatar.global_position, player_avatar.name, player_avatar.display_name)
	return player_avatar


func sync_existing_players() -> void:
	# Server sends all existing avatars to newly connected clients.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			_spawn_player_on_clients.rpc(avatar.player_id, avatar.global_position, avatar.name, avatar.display_name)


func spawn_test_npcs(count: int = -1) -> void:
	if not multiplayer.is_server():
		return

	var spawn_count: int = count
	if spawn_count <= 0:
		spawn_count = maxi(test_npc_spawn_count_on_server_start, 0)
	for _i in range(spawn_count):
		spawn_test_npc(_next_test_npc_id)
		_next_test_npc_id += 1


func spawn_test_npc(npc_id: int) -> TestNpc:
	if not multiplayer.is_server():
		return null
	if %TestNpcs.has_node("TestNpc_%d" % npc_id):
		return null

	var npc: TestNpc = TEST_NPC_SCENE.instantiate() as TestNpc
	npc.name = "TestNpc_%d" % npc_id
	npc.npc_id = npc_id
	npc.display_name = "Duck_%d" % npc_id
	npc.set_multiplayer_authority(multiplayer.get_unique_id())
	%TestNpcs.add_child(npc)

	var spawn_position: Vector3 = Vector3(
		randf_range(-test_npc_spawn_area_size, test_npc_spawn_area_size),
		1.0,
		randf_range(-test_npc_spawn_area_size, test_npc_spawn_area_size)
	)
	npc.global_position = spawn_position
	npc.set_wander_center(Vector3.ZERO, test_npc_spawn_area_size)

	_spawn_test_npc_on_clients.rpc(npc_id, spawn_position, npc.name, npc.display_name)
	return npc


func sync_existing_test_npcs_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if peer_id <= 0:
		return

	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			_spawn_test_npc_on_clients.rpc_id(peer_id, npc.npc_id, npc.global_position, npc.name, npc.display_name)


func sync_existing_dropped_items_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if peer_id <= 0:
		return
	if not has_node("DroppedItems"):
		return
	for child in %DroppedItems.get_children():
		if not (child is DroppedItem):
			continue
		var dropped_item: DroppedItem = child as DroppedItem
		_spawn_dropped_item_on_clients.rpc_id(
			peer_id,
			dropped_item.dropped_item_id,
			dropped_item.item_data_path,
			dropped_item.quantity,
			dropped_item.arc_start_position,
			dropped_item.arc_end_position,
			dropped_item.arc_duration_seconds,
			dropped_item.arc_peak_height,
			dropped_item.is_grounded
		)


func spawn_dropped_item(item_data_path: String, quantity: int, arc_start_position: Vector3, drop_target_anchor: Vector3) -> DroppedItem:
	if not multiplayer.is_server():
		return null
	var normalized_item_path: String = item_data_path.strip_edges()
	if normalized_item_path.is_empty():
		return null
	var clamped_quantity: int = maxi(quantity, 1)
	var dropped_item_id: int = _next_dropped_item_id
	_next_dropped_item_id += 1

	var arc_end_position: Vector3 = _resolve_drop_ground_position(drop_target_anchor, dropped_item_id)
	var arc_duration: float = _resolve_drop_arc_duration(arc_start_position, arc_end_position)
	var arc_peak_height: float = _resolve_drop_arc_peak_height(arc_start_position, arc_end_position)
	var dropped_item: DroppedItem = _instantiate_dropped_item(
		dropped_item_id,
		normalized_item_path,
		clamped_quantity,
		arc_start_position,
		arc_end_position,
		arc_duration,
		arc_peak_height,
		false
	)
	if dropped_item == null:
		return null

	_spawn_dropped_item_on_clients.rpc(
		dropped_item_id,
		normalized_item_path,
		clamped_quantity,
		arc_start_position,
		arc_end_position,
		arc_duration,
		arc_peak_height,
		false
	)
	return dropped_item


func notify_dropped_item_quantity_changed(dropped_item_id: int, new_quantity: int) -> void:
	if not multiplayer.is_server():
		return
	var dropped_item: DroppedItem = _find_dropped_item_by_id(dropped_item_id)
	if dropped_item == null:
		return
	var clamped_quantity: int = maxi(new_quantity, 0)
	dropped_item.set_quantity(clamped_quantity)
	_update_dropped_item_quantity_on_clients.rpc(dropped_item_id, clamped_quantity)
	if clamped_quantity <= 0:
		_remove_dropped_item_by_id_internal(dropped_item_id)
		_remove_dropped_item_on_clients.rpc(dropped_item_id)


func remove_dropped_item_by_id(dropped_item_id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_dropped_item_by_id_internal(dropped_item_id)
	_remove_dropped_item_on_clients.rpc(dropped_item_id)


func _instantiate_dropped_item(
	dropped_item_id: int,
	item_data_path: String,
	quantity: int,
	arc_start_position: Vector3,
	arc_end_position: Vector3,
	arc_duration: float,
	arc_peak_height: float,
	is_grounded: bool
) -> DroppedItem:
	if not has_node("DroppedItems"):
		return null
	var dropped_item: DroppedItem = DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	if dropped_item == null:
		return null
	dropped_item.name = "DroppedItem_%d" % dropped_item_id
	%DroppedItems.add_child(dropped_item)
	dropped_item.configure_from_network(
		dropped_item_id,
		item_data_path,
		quantity,
		arc_start_position,
		arc_end_position,
		arc_duration,
		arc_peak_height,
		is_grounded
	)
	return dropped_item


func _find_dropped_item_by_id(dropped_item_id: int) -> DroppedItem:
	if dropped_item_id <= 0:
		return null
	if not has_node("DroppedItems"):
		return null
	for child in %DroppedItems.get_children():
		if not (child is DroppedItem):
			continue
		var dropped_item: DroppedItem = child as DroppedItem
		if dropped_item.dropped_item_id == dropped_item_id:
			return dropped_item
	return null


func _remove_dropped_item_by_id_internal(dropped_item_id: int) -> void:
	var dropped_item: DroppedItem = _find_dropped_item_by_id(dropped_item_id)
	if dropped_item == null:
		return
	dropped_item.queue_free()


func _resolve_drop_ground_position(drop_target_anchor: Vector3, dropped_item_id: int) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(dropped_item_id) * 92821 + 1337
	var spread_radius: float = maxf(dropped_item_spread_radius, 0.0)
	var random_angle: float = rng.randf_range(0.0, TAU)
	var random_radius: float = rng.randf_range(0.0, spread_radius)
	var offset: Vector3 = Vector3(cos(random_angle), 0.0, sin(random_angle)) * random_radius
	var candidate_position: Vector3 = drop_target_anchor + offset
	var start_ray: Vector3 = candidate_position + Vector3.UP * 2.0
	var end_ray: Vector3 = candidate_position + Vector3.DOWN * 6.0
	var physics_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start_ray, end_ray)
	ray_params.collide_with_areas = false
	ray_params.collide_with_bodies = true
	var hit: Dictionary = physics_state.intersect_ray(ray_params)
	if hit.is_empty():
		return candidate_position + Vector3.UP * 0.15
	var hit_position: Vector3 = hit.get("position", candidate_position) as Vector3
	return hit_position + Vector3.UP * 0.15


func _resolve_drop_arc_duration(arc_start: Vector3, arc_end: Vector3) -> float:
	var horizontal_distance: float = Vector2(arc_end.x - arc_start.x, arc_end.z - arc_start.z).length()
	var normalized: float = clampf(horizontal_distance / 2.0, 0.0, 1.0)
	return lerpf(
		maxf(dropped_item_arc_duration_min_seconds, 0.1),
		maxf(dropped_item_arc_duration_max_seconds, dropped_item_arc_duration_min_seconds),
		normalized
	)


func _resolve_drop_arc_peak_height(arc_start: Vector3, arc_end: Vector3) -> float:
	var horizontal_distance: float = Vector2(arc_end.x - arc_start.x, arc_end.z - arc_start.z).length()
	return clampf(0.55 + horizontal_distance * 0.35, 0.55, 1.45)


func sync_customizations_to_peer(peer_id: int) -> void:
	# Server sends latest customization data to a newly connected client.
	if not multiplayer.is_server():
		return

	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.last_customization_json != "":
			avatar._rpc_apply_customization.rpc_id(peer_id, avatar.last_customization_json)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_on_clients(id: int, position: Vector3, player_name: String, username: String) -> void:
	# Clients execute this to create a local representation.
	if multiplayer.is_server():
		return

	if %PlayerCharacters.has_node(player_name):
		return

	print("Spawning player avatar for ID: %s" % id)

	var player_avatar := AVATAR_SCENE.instantiate() as Avatar
	player_avatar.player_id = id
	player_avatar.set_multiplayer_authority(id)
	player_avatar.name = player_name
	player_avatar.display_name = username if not username.is_empty() else player_name
	%PlayerCharacters.add_child(player_avatar)
	player_avatar.global_position = position


@rpc("authority", "call_remote", "reliable")
func _spawn_test_npc_on_clients(npc_id: int, position: Vector3, npc_name: String, display_name: String) -> void:
	if multiplayer.is_server():
		return
	if %TestNpcs.has_node(npc_name):
		return

	var npc: TestNpc = TEST_NPC_SCENE.instantiate() as TestNpc
	npc.name = npc_name
	npc.npc_id = npc_id
	npc.display_name = display_name
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id > 0:
		npc.set_multiplayer_authority(sender_peer_id)
	%TestNpcs.add_child(npc)
	npc.global_position = position
	npc.set_wander_center(Vector3.ZERO, test_npc_spawn_area_size)


@rpc("authority", "call_remote", "reliable")
func _spawn_dropped_item_on_clients(
	dropped_item_id: int,
	item_data_path: String,
	quantity: int,
	arc_start_position: Vector3,
	arc_end_position: Vector3,
	arc_duration_seconds: float,
	arc_peak_height: float,
	is_grounded: bool
) -> void:
	if multiplayer.is_server():
		return
	if _find_dropped_item_by_id(dropped_item_id) != null:
		return
	_instantiate_dropped_item(
		dropped_item_id,
		item_data_path,
		quantity,
		arc_start_position,
		arc_end_position,
		arc_duration_seconds,
		arc_peak_height,
		is_grounded
	)


@rpc("authority", "call_remote", "reliable")
func _remove_player_on_clients(id: int) -> void:
	# Clients execute this to remove the player representation.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			return


@rpc("authority", "call_remote", "reliable")
func _remove_test_npc_on_clients(npc_id: int) -> void:
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			if npc.npc_id == npc_id:
				npc.queue_free()
				return


@rpc("authority", "call_remote", "reliable")
func _update_dropped_item_quantity_on_clients(dropped_item_id: int, quantity: int) -> void:
	if multiplayer.is_server():
		return
	var dropped_item: DroppedItem = _find_dropped_item_by_id(dropped_item_id)
	if dropped_item == null:
		return
	dropped_item.set_quantity(maxi(quantity, 0))
	if quantity <= 0:
		dropped_item.queue_free()


@rpc("authority", "call_remote", "reliable")
func _remove_dropped_item_on_clients(dropped_item_id: int) -> void:
	if multiplayer.is_server():
		return
	var dropped_item: DroppedItem = _find_dropped_item_by_id(dropped_item_id)
	if dropped_item == null:
		return
	dropped_item.queue_free()


func remove_character_by_id(id: int) -> void:
	# Server removes authoritative node and notifies clients.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar and avatar.player_id == id:
			avatar.queue_free()
			break

	_remove_player_on_clients.rpc(id)


func remove_test_npc_by_id(npc_id: int) -> void:
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			var npc: TestNpc = child as TestNpc
			if npc.npc_id == npc_id:
				npc.queue_free()
				break

	_remove_test_npc_on_clients.rpc(npc_id)


func remove_all_characters() -> void:
	# Remove all player avatars from the world.
	for avatar in %PlayerCharacters.get_children():
		if avatar is Avatar:
			avatar.queue_free()
	for child in %TestNpcs.get_children():
		if child is TestNpc:
			child.queue_free()
	if has_node("DroppedItems"):
		for dropped_item in %DroppedItems.get_children():
			if dropped_item is Node:
				(dropped_item as Node).queue_free()
