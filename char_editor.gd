class_name CharEditor
extends Control

static var CHAR_PATH:String = "res://assets/char/"

@onready var option_scene:PackedScene = load("uid://c83twyarpre66")

@onready var char:Char = %Char
@onready var save_button:Button = %SaveButton
@onready var load_button:Button = %LoadButton

var char_customization_options:Array[CharCustomizeOption]

func _ready() -> void:
	char.customized.connect(update_options)
	
	save_button.pressed.connect(func():
		Char.save_customision(char))
	load_button.pressed.connect(func():
		Char.load_customization(char))
	
	char_customization_options.assign(get_tree().get_nodes_in_group("char_option"))
	setup_options()
	update_options()

func setup_options():
	for option in char_customization_options:
		option.value_changed.connect(on_char_options_changed.bind(option.modified_polygons))

func update_options():
	for option in char_customization_options:
		option.set_index(get_customization_index(char,option.modified_polygons[0]),true)

func on_char_options_changed(index:int, options:Array[String]):
	for option in options:
		char.change_polygon_texture(option, get_customization_options(option)[index])
		char.play_anim_once("emote_hi")

static func get_customization_options(option_name:String) -> Array:
	var path:String = "%s%s" % [CHAR_PATH, option_name]
	var files:Array = Array(DirAccess.get_files_at(path))
	files = files.filter(func (x:String): return !x.contains("import"))
	files = files.map(func (x:String): return x.insert(0,"%s%s/" % [CHAR_PATH, option_name]))
	return files

static func get_customization_index(_char:Char, option_name:String) -> int:
	var poly:Polygon2D = _char.polygons.filter(
		func (x:Polygon2D):
		return true if x.name == option_name else false
	).pop_front()
	
	if !poly: printerr("Invalid polygon name"); return 0
	
	var texture_path:String = poly.texture.resource_path
	var options:Array = get_customization_options(option_name)
	return options.find(texture_path)
