class_name CharEditor
extends Control

static var CHAR_PATH:String = "res://assets/char/"

@onready var option_scene:PackedScene = load("uid://c83twyarpre66")

@onready var options_container:VBoxContainer = %OptionsContainer
@onready var char:Char = %Char

func _ready() -> void:
	populate_options()

func populate_options():
	var polygons:Array[Polygon2D] = char.polygons
	for poly in polygons:
		var option:IncrementalOption = option_scene.instantiate()
		options_container.add_child(option)
		var options = get_customization_options(poly.name)
		option.setup(poly.name, options)
		option.value_changed.connect(on_options_changed.bind(poly.name))


func on_options_changed(index:int, option_name:String):
	char.change_polygon_texture(option_name, get_customization_options(option_name)[index])
	print("option_changed")

static func get_customization_options(option_name:String) -> Array:
	var path:String = "%s%s" % [CHAR_PATH, option_name]
	var files:Array = Array(DirAccess.get_files_at(path))
	files = files.filter(func (x:String): return !x.contains("import"))
	files = files.map(func (x:String): return x.insert(0,"%s%s/" % [CHAR_PATH, option_name]))
	return files
	
