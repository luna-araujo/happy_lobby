class_name PlayerUiInspector
extends Node

signal inspect_target_avatar_selected(target_avatar: Avatar)
signal inspect_target_inventory_requested(target_avatar: Avatar)
signal inspect_target_cleared

@export var inspect_action: StringName = &"inspect_target"
@export var inspect_distance: float = 20.0

var _local_avatar: Avatar
var _context_menu: PopupMenu
var _context_target_avatar: Avatar

const CONTEXT_INSPECT_INVENTORY: int = 0


func _ready() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "InspectorContextMenu"
	add_child(_context_menu)
	if not _context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
		_context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func set_local_avatar(avatar: Avatar) -> void:
	_local_avatar = avatar


func clear_local_avatar() -> void:
	_local_avatar = null
	_context_target_avatar = null
	if _context_menu != null:
		_context_menu.hide()
	inspect_target_cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _local_avatar == null or not is_instance_valid(_local_avatar):
		return
	if UIManager != null and UIManager.mouse_locked:
		return
	if not event.is_action_pressed(String(inspect_action)):
		return

	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		return

	var camera: Camera3D = _resolve_active_camera()
	if camera == null:
		inspect_target_cleared.emit()
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var from_position: Vector3 = camera.project_ray_origin(mouse_position)
	var to_position: Vector3 = from_position + camera.project_ray_normal(mouse_position) * maxf(inspect_distance, 0.1)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false

	var world_3d: World3D = _local_avatar.get_world_3d()
	if world_3d == null:
		inspect_target_cleared.emit()
		return
	var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		inspect_target_cleared.emit()
		return

	var collider_variant: Variant = result.get("collider", null)
	if not (collider_variant is Node):
		inspect_target_cleared.emit()
		return
	var collider_node: Node = collider_variant as Node
	var target_avatar: Avatar = _resolve_avatar_from_node(collider_node)
	if target_avatar == null:
		_context_target_avatar = null
		if _context_menu != null:
			_context_menu.hide()
		inspect_target_cleared.emit()
		return
	if target_avatar == _local_avatar:
		_context_target_avatar = null
		if _context_menu != null:
			_context_menu.hide()
		inspect_target_cleared.emit()
		return
	_open_context_menu_for_avatar(target_avatar)


func _resolve_active_camera() -> Camera3D:
	if _local_avatar != null and is_instance_valid(_local_avatar):
		if _local_avatar.third_person_camera != null and is_instance_valid(_local_avatar.third_person_camera):
			if _local_avatar.third_person_camera.camera_3d != null:
				return _local_avatar.third_person_camera.camera_3d
	return get_viewport().get_camera_3d()


func _resolve_avatar_from_node(node: Node) -> Avatar:
	var current: Node = node
	while current != null:
		if current is Avatar:
			return current as Avatar
		current = current.get_parent()
	return null


func _open_context_menu_for_avatar(target_avatar: Avatar) -> void:
	if _context_menu == null:
		return
	_context_target_avatar = target_avatar
	_context_menu.clear()
	_context_menu.add_item("Inspect Inventory", CONTEXT_INSPECT_INVENTORY)
	var screen_pos: Vector2i = DisplayServer.mouse_get_position()
	_context_menu.popup(Rect2i(screen_pos, Vector2i(1, 1)))
	inspect_target_avatar_selected.emit(target_avatar)


func _on_context_menu_id_pressed(action_id: int) -> void:
	if action_id != CONTEXT_INSPECT_INVENTORY:
		return
	if _context_target_avatar == null or not is_instance_valid(_context_target_avatar):
		inspect_target_cleared.emit()
		return
	inspect_target_inventory_requested.emit(_context_target_avatar)
