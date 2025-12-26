class_name Char
extends Node2D

signal customized;

var animation_player:AnimationPlayer 

var polygons:Array[Polygon2D]
var char_name:String = "noName"
var skin_tone:Color = Color("f2b089")
var height:float = 1;


func _ready() -> void:
	$Polygons.get_children().map(func (x): polygons.append(x))
	animation_player = $AnimationPlayer

func play_anim_once(anim_name:String):
	animation_player.play(anim_name)
	await animation_player.animation_finished
	animation_player.play("idle")

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

static func save_customision(char:Char):
	var save_data = {
		"textures" : {}
	}
	for poly in char.polygons:
		save_data.textures[poly.name] = poly.texture.resource_path
	
	var json_string:String = JSON.stringify(save_data,"\t")
	var file = FileAccess.open("user://user_char.json", FileAccess.WRITE)
	file.store_string(json_string)

static func load_customization(char:Char):
	var json_string = FileAccess.open("user://user_char.json", FileAccess.READ).get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data_received:Dictionary = json.data
		var textures:Dictionary = data_received["textures"]
		char.polygons.map(
			func (x):
			var i = 0
			for texture in textures.keys():
				i+=1
				if x.name == texture:
					x.texture = ResourceLoader.load(textures[texture])
			return true )
		char.customized.emit()
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
