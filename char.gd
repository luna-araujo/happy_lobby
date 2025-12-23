class_name Char
extends Node2D

var polygons:Array[Polygon2D]


func _ready() -> void:
	$Polygons.get_children().map(func (x): polygons.append(x))

func change_polygon_texture(polygon_name:String,texture_path:String):
	var poly:Polygon2D = polygons.filter(
		func (x:Polygon2D):
			return true if x.name == polygon_name else false
	).pop_front()
	
	if !poly: printerr("Invalid polygon name"); return
	
	var new_texture:Texture2D = ResourceLoader.load(texture_path)
	if !new_texture: printerr("Invalid texture_path"); return
	
	poly.texture = new_texture
