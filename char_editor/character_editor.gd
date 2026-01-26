class_name CharEditor
extends Control

static var CHAR_PATH:String = "res://assets/char/"

@onready var option_scene:PackedScene = load("uid://c83twyarpre66")

@onready var character:Character = %Char
@onready var save_button:Button = %SaveButton
@onready var load_button:Button = %LoadButton

var char_customization_options:Array[Node] = []

func _ready() -> void:
	character.customized.connect(update_options)
	
	save_button.pressed.connect(func():
		Character.store_save(character))
	load_button.pressed.connect(func():
		Character.load_save(character))
	
	char_customization_options.assign(get_tree().get_nodes_in_group("char_option"))
	setup_options()
	update_options()

func setup_options():
	for option in char_customization_options:
		if option is CharCustomizeOption:
			option.value_changed.connect(on_char_options_changed.bind(option.modified_polygons))
		elif  option is ColorPickerOption:
			option.value_changed.connect(on_char_color_changed.bind(option.option_id))

func update_options():
	for option in char_customization_options:
		if option is CharCustomizeOption:
			option.set_index(get_customization_index(character,option.modified_polygons[0]),true)


func on_char_options_changed(index:int, options:Array[String]):
	for option in options:
		character.change_polygon_texture(option, get_customization_options(option)[index])
		character.play_anim_once("emote_hi")

func on_char_color_changed(new_color:Color,option_name:String):
	var char_shader:ShaderMaterial = character.get_material()
	match option_name:
		"skin_color":
			char_shader.set_shader_parameter(option_name, new_color)

static func get_customization_options(option_name:String) -> Array:
	var path:String = "%s%s" % [CHAR_PATH, option_name]
	var files:Array = Array(DirAccess.get_files_at(path))
	files = files.filter(func (x:String): return !x.contains("import"))
	files = files.map(func (x:String): return x.insert(0,"%s%s/" % [CHAR_PATH, option_name]))
	return files

static func get_customization_index(_char:Character, option_name:String) -> int:
	var poly:Polygon2D = _char.polygons.filter(
		func (x:Polygon2D):
		return true if x.name == option_name else false
	).pop_front()
	
	if !poly: printerr("Invalid polygon name"); return 0
	
	var texture_path:String = poly.texture.resource_path
	var options:Array = get_customization_options(option_name)
	return options.find(texture_path)
