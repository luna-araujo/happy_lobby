class_name Character
extends CharacterBody2D

signal customized;

var player_id:int = 1:
	set(id):
		player_id = id
		$PlayerInput.set_multiplayer_authority(id)

var animation_player:AnimationPlayer 
var input:PlayerInput = null

var polygons:Array[Polygon2D]
var skeleton:Skeleton2D = null
var char_name:String = "noName"
var skin_tone:Color = Color("f2b089")
var height:float = 1;


func _ready() -> void:
	$Polygons.get_children().map(func (x): polygons.append(x))
	skeleton = $Skeleton2D
	animation_player = $AnimationPlayer
	input = $PlayerInput


func play_anim_once(anim_name:String):
	animation_player.play(anim_name)
	await animation_player.animation_finished
	animation_player.play("idle")

func set_height(new_height:float):
	var all_bones:Array[Bone2D]
	for i in skeleton.get_bone_count():
		all_bones.append(skeleton.get_bone(i))
	for bone in all_bones:
		if bone.is_in_group("height_bone"):
			bone.scale.y = new_height
	height = new_height

func get_polygons_material() -> ShaderMaterial:
	return polygons[0].material as ShaderMaterial

func change_polygon_texture(polygon_name:String,texture_path:String):
	var poly:Polygon2D = polygons.filter(
		func (x:Polygon2D):
			return true if x.name == polygon_name else false
	).pop_front()
	
	if !poly: printerr("Invalid polygon name"); return
	
	var new_texture:Texture2D = ResourceLoader.load(texture_path)
	if !new_texture: printerr("Invalid texture_path"); return
	
	poly.texture = new_texture
	customized.emit()



const LOCAL_PLAYER_FILE:String = "user://user_char.json"
const COLOR_PARAMS:Array[String] = [
	"skin_color",
	"hair_color",
	"eyes_color",
	"upper_color",
	"bottom_color",
	"shoes_color",
	"accent_upper",
	"accent_bottom"
]

static func store_save(character:Character):
	var save_data = {
		"textures" : {},
		"colors" : {}
	}
	for poly in character.polygons:
		save_data.textures[poly.name] = poly.texture.resource_path
	
	var char_shader := character.get_material() as ShaderMaterial
	if char_shader:
		for param in COLOR_PARAMS:
			var value = char_shader.get_shader_parameter(param)
			if typeof(value) == TYPE_COLOR:
				save_data.colors[param] = value.to_html(true)
	
	var json_string:String = JSON.stringify(save_data,"\t")
	var file = FileAccess.open(LOCAL_PLAYER_FILE, FileAccess.WRITE)
	file.store_string(json_string)

static func load_save(character:Character, path:String=""):
	var json_string = FileAccess.open(LOCAL_PLAYER_FILE, FileAccess.READ).get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data_received:Dictionary = json.data
		var textures:Dictionary = data_received["textures"]
		character.polygons.map(
			func (x):
			var i = 0
			for texture in textures.keys():
				i+=1
				if x.name == texture:
					x.texture = ResourceLoader.load(textures[texture])
			return true )
		if data_received.has("colors"):
			var char_shader := character.get_material() as ShaderMaterial
			if char_shader:
				for param in data_received.colors.keys():
					var color_value = Color(data_received.colors[param])
					char_shader.set_shader_parameter(param, color_value)
		character.customized.emit()
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
