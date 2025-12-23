class_name CharEditor
extends Control

static var CHAR_PATH:String = "res://assets/char/"

@onready var option_scene:PackedScene = load("uid://c83twyarpre66")

@onready var char:Char = %Char

var char_customization_options:Array[CharCustomizeOption]

func _ready() -> void:
	char_customization_options.assign(get_tree().get_nodes_in_group("char_option"))
	for option in char_customization_options:
		option.value_changed.connect(on_char_options_changed.bind(option.modified_polygons))

func on_char_options_changed(index:int, options:Array[String]):
	for option in options:
		char.change_polygon_texture(option, get_customization_options(option)[index])

static func get_customization_options(option_name:String) -> Array:
	var path:String = "%s%s" % [CHAR_PATH, option_name]
	var files:Array = Array(DirAccess.get_files_at(path))
	files = files.filter(func (x:String): return !x.contains("import"))
	files = files.map(func (x:String): return x.insert(0,"%s%s/" % [CHAR_PATH, option_name]))
	return files
	
