class_name AvatarCustomization
extends Node

signal customized

var mesh_instances: Array[MeshInstance3D] = []
var polygons: Array[MeshInstance3D] = []
var skeleton: Skeleton3D = null
var height: float = 1.0

@export var height_scale_target: NodePath = NodePath("../Armature")

const LOCAL_PLAYER_FILE: String = "user://user_avatar.json"
const COLOR_PARAMS: Array[String] = [
	"base_color",
	"skin_color",
	"hair_color",
	"eyes_color",
	"upper_color",
	"bottom_color",
	"shoes_color",
	"accent_upper",
	"accent_bottom"
]
const TEXTURE_PARAMS: Array[String] = [
	"albedo_texture",
	"texture_albedo",
	"main_texture",
	"base_texture"
]


func _ready() -> void:
	refresh_scene_refs()


func refresh_scene_refs() -> void:
	var avatar_root := get_parent()
	if not avatar_root:
		mesh_instances.clear()
		polygons.clear()
		skeleton = null
		return

	skeleton = avatar_root.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	mesh_instances = _find_mesh_instances(avatar_root)
	polygons.assign(mesh_instances)


func set_height(new_height: float) -> void:
	var target := get_node_or_null(height_scale_target) as Node3D
	if target:
		var current_scale := target.scale
		current_scale.y = new_height
		target.scale = current_scale
	height = new_height


func get_material() -> ShaderMaterial:
	for mesh in mesh_instances:
		if not is_instance_valid(mesh):
			continue
		for surface_idx in _surface_count(mesh):
			var override_material := mesh.get_surface_override_material(surface_idx)
			if override_material is ShaderMaterial:
				return override_material as ShaderMaterial
			if mesh.mesh and surface_idx >= 0 and surface_idx < mesh.mesh.get_surface_count():
				var base_material := mesh.mesh.surface_get_material(surface_idx)
				if base_material is ShaderMaterial:
					var new_material := (base_material as ShaderMaterial).duplicate(true) as ShaderMaterial
					mesh.set_surface_override_material(surface_idx, new_material)
					return new_material
		var override_mat := mesh.material_override
		if override_mat is ShaderMaterial:
			return override_mat as ShaderMaterial
	return null


func get_polygons_material() -> ShaderMaterial:
	return get_material()


func change_polygon_texture(polygon_name: String, texture_path: String) -> void:
	var mesh := _find_mesh_instance_by_name(polygon_name)
	if not mesh:
		printerr("Invalid mesh name")
		return

	var new_texture := ResourceLoader.load(texture_path)
	if not new_texture or not (new_texture is Texture2D):
		printerr("Invalid texture_path")
		return

	var texture_2d := new_texture as Texture2D
	var applied := false

	for surface_idx in _surface_count(mesh):
		var material := _material_for_surface(mesh, surface_idx)
		if _set_texture_on_material(material, texture_2d):
			mesh.set_surface_override_material(surface_idx, material)
			applied = true

	if not applied:
		var material := mesh.material_override
		if not material:
			material = _material_for_surface(mesh, 0)
		if _set_texture_on_material(material, texture_2d):
			mesh.material_override = material
			applied = true

	if not applied:
		printerr("No compatible material found on mesh: %s" % polygon_name)
		return

	customized.emit()


func store_save(path: String = LOCAL_PLAYER_FILE) -> void:
	var save_data := {
		"textures": {},
		"colors": {},
		"height": height
	}

	for mesh in mesh_instances:
		if not is_instance_valid(mesh):
			continue
		var mesh_textures: Dictionary = {}
		for surface_idx in _surface_count(mesh):
			var mat := _material_for_surface(mesh, surface_idx)
			var texture_path := _extract_texture_path(mat)
			if not texture_path.is_empty():
				mesh_textures[str(surface_idx)] = texture_path
		if not mesh_textures.is_empty():
			save_data.textures[mesh.name] = mesh_textures

	var char_shader := get_material()
	if char_shader:
		for param in COLOR_PARAMS:
			var value = char_shader.get_shader_parameter(param)
			if typeof(value) == TYPE_COLOR:
				save_data.colors[param] = (value as Color).to_html(true)

	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)


func load_save(path: String = LOCAL_PLAYER_FILE) -> void:
	var json_string := read_customization_json(path)
	if json_string.is_empty():
		return
	apply_customization_from_json(json_string)


func read_customization_json(path: String = LOCAL_PLAYER_FILE) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	return file.get_as_text()


func apply_customization_from_json(json_string: String) -> void:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error == OK:
		apply_customization_data(json.data)
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())


func apply_customization_data(data_received: Dictionary) -> void:
	if data_received.has("textures"):
		var textures: Dictionary = data_received["textures"]
		for mesh_name in textures.keys():
			var mesh := _find_mesh_instance_by_name(str(mesh_name))
			if not mesh:
				continue

			var mesh_texture_data = textures[mesh_name]
			if mesh_texture_data is Dictionary:
				for surface_key in (mesh_texture_data as Dictionary).keys():
					var surface_idx := int(surface_key)
					var texture_path := str((mesh_texture_data as Dictionary)[surface_key])
					_apply_texture_to_surface(mesh, surface_idx, texture_path)
			elif mesh_texture_data is String:
				_apply_texture_to_surface(mesh, 0, str(mesh_texture_data))

	if data_received.has("colors"):
		var colors: Dictionary = data_received["colors"]
		var char_shader := get_material()
		if char_shader:
			for param in colors.keys():
				char_shader.set_shader_parameter(param, Color(colors[param]))

	if data_received.has("height"):
		set_height(float(data_received["height"]))

	customized.emit()


func _find_mesh_instance_by_name(mesh_name: String) -> MeshInstance3D:
	for mesh in mesh_instances:
		if is_instance_valid(mesh) and mesh.name == mesh_name:
			return mesh
	return null


func _apply_texture_to_surface(mesh: MeshInstance3D, surface_idx: int, texture_path: String) -> void:
	var loaded := ResourceLoader.load(texture_path)
	if not loaded or not (loaded is Texture2D):
		return

	var texture := loaded as Texture2D
	var material := _material_for_surface(mesh, surface_idx)
	if _set_texture_on_material(material, texture):
		mesh.set_surface_override_material(surface_idx, material)


func _extract_texture_path(material: Material) -> String:
	if material is BaseMaterial3D:
		var albedo := (material as BaseMaterial3D).albedo_texture
		if albedo:
			return albedo.resource_path

	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for param in TEXTURE_PARAMS:
			var value = shader_material.get_shader_parameter(param)
			if value is Texture2D:
				return (value as Texture2D).resource_path

	return ""


func _material_for_surface(mesh: MeshInstance3D, surface_idx: int) -> Material:
	var material := mesh.get_surface_override_material(surface_idx)
	if material:
		return material.duplicate(true)

	if mesh.mesh and surface_idx >= 0 and surface_idx < mesh.mesh.get_surface_count():
		var base := mesh.mesh.surface_get_material(surface_idx)
		if base:
			return base.duplicate(true)

	if mesh.material_override:
		return mesh.material_override.duplicate(true)

	return StandardMaterial3D.new()


func _set_texture_on_material(material: Material, texture: Texture2D) -> bool:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).albedo_texture = texture
		return true

	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for param in TEXTURE_PARAMS:
			shader_material.set_shader_parameter(param, texture)
		return true

	return false


func _surface_count(mesh: MeshInstance3D) -> int:
	if mesh.mesh:
		return mesh.mesh.get_surface_count()
	return mesh.get_surface_override_material_count()


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_find_mesh_instances(child))
	return found
