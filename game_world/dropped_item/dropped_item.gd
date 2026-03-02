class_name DroppedItem
extends Node3D

@export var pickup_distance: float = 2.5
@export var bob_amplitude: float = 0.08
@export var bob_frequency_hz: float = 0.9
@export var bob_spin_degrees_per_second: float = 28.0
@export var bob_height_offset: float = 0.14

@onready var _visual_root: Node3D = $VisualRoot
@onready var _sprite_a: Sprite3D = $VisualRoot/SpriteA
@onready var _sprite_b: Sprite3D = $VisualRoot/SpriteB
@onready var _sprite_c: Sprite3D = $VisualRoot/SpriteC
@onready var _quantity_label: Label3D = $VisualRoot/QuantityLabel

var dropped_item_id: int = 0
var item_data_path: String = ""
var quantity: int = 1
var arc_start_position: Vector3 = Vector3.ZERO
var arc_end_position: Vector3 = Vector3.ZERO
var arc_duration_seconds: float = 0.45
var arc_peak_height: float = 0.85
var is_grounded: bool = false

var _arc_started_at_seconds: float = 0.0
var _bob_base_position: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _cached_item_data: Resource
static var _fallback_icon: Texture2D


func _ready() -> void:
	add_to_group("DroppedItem")
	_apply_spawn_state()


func _process(delta: float) -> void:
	if not is_grounded:
		_update_arc_motion()
	else:
		_update_bob_motion(delta)
	_face_label_towards_camera()


func configure_from_network(
	new_dropped_item_id: int,
	new_item_data_path: String,
	new_quantity: int,
	new_arc_start_position: Vector3,
	new_arc_end_position: Vector3,
	new_arc_duration_seconds: float,
	new_arc_peak_height: float,
	new_is_grounded: bool
) -> void:
	dropped_item_id = maxi(new_dropped_item_id, 1)
	item_data_path = new_item_data_path.strip_edges()
	quantity = maxi(new_quantity, 1)
	arc_start_position = new_arc_start_position
	arc_end_position = new_arc_end_position
	arc_duration_seconds = maxf(new_arc_duration_seconds, 0.1)
	arc_peak_height = maxf(new_arc_peak_height, 0.1)
	is_grounded = new_is_grounded
	_cached_item_data = null
	_apply_spawn_state()


func set_quantity(new_quantity: int) -> void:
	quantity = maxi(new_quantity, 0)
	_refresh_visuals()


func get_display_name() -> String:
	var item_data: Resource = _resolve_item_data()
	if item_data != null:
		var display_name_variant: Variant = item_data.get("display_name")
		var display_name: String = String(display_name_variant).strip_edges()
		if not display_name.is_empty():
			return display_name
		var item_id_variant: Variant = item_data.get("item_id")
		var item_id: String = String(item_id_variant).strip_edges()
		if not item_id.is_empty():
			return item_id
	var fallback_name: String = item_data_path.get_file().get_basename().strip_edges()
	if fallback_name.is_empty():
		return "Item"
	return fallback_name


func can_be_picked_by_avatar(target_avatar: Avatar) -> bool:
	if quantity <= 0:
		return false
	if not is_grounded:
		return false
	if target_avatar == null:
		return false
	if target_avatar.inventory == null:
		return false
	if not _is_avatar_within_pickup_distance(target_avatar):
		return false
	var addable_quantity: int = _resolve_addable_quantity(target_avatar.inventory, item_data_path, quantity)
	return addable_quantity > 0


func can_be_picked_by_server(target_avatar: Avatar, peer_id: int) -> bool:
	if target_avatar == null:
		return false
	if peer_id <= 0:
		return false
	if target_avatar.player_id != peer_id:
		return false
	return can_be_picked_by_avatar(target_avatar)


func try_pickup_to_player(player_peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if quantity <= 0:
		return false
	if player_peer_id <= 0:
		return false
	if not is_grounded:
		return false

	var target_avatar: Avatar = _find_avatar_by_player_id(player_peer_id)
	if target_avatar == null:
		return false
	if target_avatar.inventory == null:
		return false
	if not can_be_picked_by_server(target_avatar, player_peer_id):
		return false

	var addable_quantity: int = _resolve_addable_quantity(target_avatar.inventory, item_data_path, quantity)
	if addable_quantity <= 0:
		return false

	var remaining_after_add: int = target_avatar.inventory.add_item(item_data_path, addable_quantity)
	var moved_quantity: int = addable_quantity - remaining_after_add
	if moved_quantity <= 0:
		return false

	var world: NeoWorld = _find_world_root()
	if world == null:
		return false

	var new_quantity: int = quantity - moved_quantity
	if new_quantity <= 0:
		world.remove_dropped_item_by_id(dropped_item_id)
	else:
		world.notify_dropped_item_quantity_changed(dropped_item_id, new_quantity)
	return true


func _apply_spawn_state() -> void:
	_refresh_visuals()
	_bob_phase = float(dropped_item_id % 997) / 997.0 * TAU
	if is_grounded:
		_bob_base_position = arc_end_position + Vector3(0.0, maxf(bob_height_offset, 0.0), 0.0)
		global_position = _bob_base_position
		return
	global_position = arc_start_position
	_arc_started_at_seconds = float(Time.get_ticks_msec()) / 1000.0


func _update_arc_motion() -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var elapsed: float = maxf(now_seconds - _arc_started_at_seconds, 0.0)
	var progress: float = clampf(elapsed / maxf(arc_duration_seconds, 0.1), 0.0, 1.0)
	var travel_position: Vector3 = arc_start_position.lerp(arc_end_position, progress)
	travel_position.y += sin(progress * PI) * maxf(arc_peak_height, 0.1)
	global_position = travel_position
	if progress < 1.0:
		return
	is_grounded = true
	_bob_base_position = arc_end_position + Vector3(0.0, maxf(bob_height_offset, 0.0), 0.0)
	global_position = _bob_base_position


func _update_bob_motion(delta: float) -> void:
	if _visual_root == null:
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var bob_offset_y: float = sin(time_seconds * TAU * maxf(bob_frequency_hz, 0.01) + _bob_phase) * bob_amplitude
	global_position = Vector3(_bob_base_position.x, _bob_base_position.y + bob_offset_y, _bob_base_position.z)
	var spin_radians_per_second: float = deg_to_rad(bob_spin_degrees_per_second)
	_visual_root.rotate_y(spin_radians_per_second * maxf(delta, 0.0))


func _face_label_towards_camera() -> void:
	if _quantity_label == null:
		return
	if not _quantity_label.visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var label_position: Vector3 = _quantity_label.global_position
	var target_position: Vector3 = camera.global_position
	if label_position.distance_squared_to(target_position) <= 0.0001:
		return
	_quantity_label.look_at(target_position, Vector3.UP)


func _refresh_visuals() -> void:
	var icon_texture: Texture2D = _resolve_icon_texture()
	if _sprite_a != null:
		_sprite_a.texture = icon_texture
	if _sprite_b != null:
		_sprite_b.texture = icon_texture
	if _sprite_c != null:
		_sprite_c.texture = icon_texture

	var visible_stack_count: int = clampi(quantity, 0, 3)
	if _sprite_a != null:
		_sprite_a.visible = visible_stack_count >= 1
	if _sprite_b != null:
		_sprite_b.visible = visible_stack_count >= 2
	if _sprite_c != null:
		_sprite_c.visible = visible_stack_count >= 3

	if _quantity_label != null:
		_quantity_label.visible = quantity > 3
		if quantity > 3:
			_quantity_label.text = "x%d" % quantity


func _resolve_icon_texture() -> Texture2D:
	var item_data: Resource = _resolve_item_data()
	if item_data != null:
		var icon_variant: Variant = item_data.get("icon")
		if icon_variant is Texture2D:
			return icon_variant as Texture2D
	if _fallback_icon != null:
		return _fallback_icon
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.94, 0.94, 0.94, 0.95))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_fallback_icon = texture
	return _fallback_icon


func _resolve_item_data() -> Resource:
	if _cached_item_data != null:
		return _cached_item_data
	if item_data_path.is_empty():
		return null
	var loaded: Resource = load(item_data_path)
	if loaded != null:
		_cached_item_data = loaded
	return _cached_item_data


func _resolve_addable_quantity(target_inventory: Inventory, target_item_path: String, requested_quantity: int) -> int:
	if target_inventory == null:
		return 0
	if requested_quantity <= 0:
		return 0
	if target_inventory.has_method("get_addable_quantity"):
		var addable_variant: Variant = target_inventory.call("get_addable_quantity", target_item_path, requested_quantity)
		if typeof(addable_variant) == TYPE_INT:
			return maxi(int(addable_variant), 0)

	var addable: int = 0
	for amount in range(1, requested_quantity + 1):
		if target_inventory.can_add_item(target_item_path, amount):
			addable = amount
		else:
			break
	return addable


func _is_avatar_within_pickup_distance(target_avatar: Avatar) -> bool:
	if target_avatar == null:
		return false
	var avatar_position: Vector3 = target_avatar.global_position
	if target_avatar.movement_body != null and is_instance_valid(target_avatar.movement_body):
		avatar_position = target_avatar.movement_body.global_position
	var max_distance: float = maxf(pickup_distance, 0.1)
	return avatar_position.distance_to(global_position) <= max_distance


func _find_avatar_by_player_id(target_player_id: int) -> Avatar:
	if target_player_id <= 0:
		return null
	var root: Node = get_tree().root
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		if current is Avatar:
			var avatar_node: Avatar = current as Avatar
			if avatar_node.player_id == target_player_id:
				return avatar_node
		for child in current.get_children():
			if child is Node:
				stack.push_back(child)
	return null


func _find_world_root() -> NeoWorld:
	var current: Node = self
	while current != null:
		if current is NeoWorld:
			return current as NeoWorld
		current = current.get_parent()
	return null
