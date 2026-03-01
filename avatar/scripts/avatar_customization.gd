class_name AvatarCustomization
extends Node

signal customized

var mesh_instances: Array[MeshInstance3D] = []
var polygons: Array[MeshInstance3D] = []
var skeleton: Skeleton3D = null


const LOCAL_PLAYER_FILE: String = "user://user_avatar.json"
const COLOR_PARAMS: Array[String] = [
	"skin_color",
	"avatar_color"
]
const TEXTURE_PARAMS: Array[String] = [
	"albedo_texture",
	"texture_albedo",
	"main_texture",
	"base_texture"
]
const DEFAULT_SKIN_COLOR := Color("f2b089")
const DEFAULT_AVATAR_COLOR := Color(0.05958981, 0.37908173, 0.7411243, 1.0)

var color_slots: Dictionary = {}


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
	_refresh_color_slots()


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


func get_available_color_options() -> Array[String]:
	return COLOR_PARAMS.duplicate()


func set_color(option_name: String, new_color: Color) -> void:
	_set_color_internal(option_name, new_color, true)


func get_color(option_name: String) -> Color:
	var normalized_option := _normalize_color_option(option_name)
	if normalized_option.is_empty():
		return Color.WHITE
	if color_slots.is_empty():
		_refresh_color_slots()

	var slot_data = color_slots.get(normalized_option, {})
	if slot_data.is_empty():
		return _default_color_for_option(normalized_option)

	var mesh := slot_data.get("mesh", null) as MeshInstance3D
	var surface_idx := int(slot_data.get("surface_idx", 0))
	if not is_instance_valid(mesh):
		return _default_color_for_option(normalized_option)

	var material := _get_effective_surface_material(mesh, surface_idx)
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var value = shader_material.get_shader_parameter("base_color")
		if typeof(value) == TYPE_COLOR:
			return value as Color

	return _default_color_for_option(normalized_option)


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

	for param in COLOR_PARAMS:
		save_data.colors[param] = get_color(param).to_html(true)

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
		for param in colors.keys():
			var normalized_option := _normalize_color_option(str(param))
			if normalized_option.is_empty():
				continue
			_set_color_internal(normalized_option, Color(colors[param]), false)

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


func _set_color_internal(option_name: String, new_color: Color, emit_signal: bool) -> void:
	var normalized_option := _normalize_color_option(option_name)
	if normalized_option.is_empty():
		return
	if color_slots.is_empty():
		_refresh_color_slots()

	var slot_data = color_slots.get(normalized_option, {})
	if slot_data.is_empty():
		return

	var mesh := slot_data.get("mesh", null) as MeshInstance3D
	var surface_idx := int(slot_data.get("surface_idx", 0))
	if not is_instance_valid(mesh):
		return

	var material := _material_for_surface(mesh, surface_idx)
	if not (material is ShaderMaterial):
		return

	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("base_color", new_color)
	mesh.set_surface_override_material(surface_idx, shader_material)

	if emit_signal:
		customized.emit()


func _normalize_color_option(option_name: String) -> String:
	match option_name:
		"skin_color":
			return "skin_color"
		"avatar_color", "base_color":
			return "avatar_color"
		_:
			return ""


func _default_color_for_option(option_name: String) -> Color:
	match option_name:
		"skin_color":
			return DEFAULT_SKIN_COLOR
		"avatar_color":
			return DEFAULT_AVATAR_COLOR
		_:
			return Color.WHITE


func _refresh_color_slots() -> void:
	color_slots.clear()
	var candidates: Array[Dictionary] = []

	for mesh in mesh_instances:
		if not is_instance_valid(mesh):
			continue
		for surface_idx in _surface_count(mesh):
			var material := _get_effective_surface_material(mesh, surface_idx)
			if not (material is ShaderMaterial):
				continue

			var shader_material := material as ShaderMaterial
			if not _shader_has_param(shader_material, "base_color"):
				continue

			var color_value: Variant = shader_material.get_shader_parameter("base_color")
			if typeof(color_value) != TYPE_COLOR:
				continue

			candidates.append({
				"mesh": mesh,
				"surface_idx": surface_idx,
				"color": color_value as Color
			})

	if candidates.is_empty():
		return

	var skin_candidate_idx := _pick_closest_candidate(candidates, DEFAULT_SKIN_COLOR, -1)
	var avatar_candidate_idx := _pick_closest_candidate(candidates, DEFAULT_AVATAR_COLOR, skin_candidate_idx)

	color_slots["skin_color"] = candidates[skin_candidate_idx]
	color_slots["avatar_color"] = candidates[avatar_candidate_idx]


func _pick_closest_candidate(candidates: Array[Dictionary], target: Color, exclude_idx: int) -> int:
	var best_idx := -1
	var best_distance := INF

	for idx in candidates.size():
		if idx == exclude_idx:
			continue
		var candidate := candidates[idx]
		var candidate_color := candidate.get("color", Color.WHITE) as Color
		var distance := _color_distance_sq(candidate_color, target)
		if distance < best_distance:
			best_distance = distance
			best_idx = idx

	if best_idx >= 0:
		return best_idx
	return 0


func _color_distance_sq(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return dr * dr + dg * dg + db * db


func _get_effective_surface_material(mesh: MeshInstance3D, surface_idx: int) -> Material:
	var override_material := mesh.get_surface_override_material(surface_idx)
	if override_material:
		return override_material

	if mesh.mesh and surface_idx >= 0 and surface_idx < mesh.mesh.get_surface_count():
		return mesh.mesh.surface_get_material(surface_idx)

	if mesh.material_override:
		return mesh.material_override

	return null


func _shader_has_param(material: ShaderMaterial, parameter_name: String) -> bool:
	var shader := material.shader
	if not shader:
		return false

	for uniform in shader.get_shader_uniform_list():
		if uniform is Dictionary and uniform.get("name", "") == parameter_name:
			return true

	return false
