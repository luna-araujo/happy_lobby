class_name SteamInfo
extends PanelContainer

@onready var avatar:TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/Avatar
@onready var steam_name:Label = $MarginContainer/VBoxContainer/HBoxContainer/SteamName
@onready var stats:RichTextLabel = $MarginContainer/VBoxContainer/SteamStats

func _ready() -> void:
	if NetworkManager.using_steam == false:
		steam_name.text = "Not running on Steam"
		return
	
	NetworkManager.avatar_loaded.connect(_on_avatar_loaded)
	


func _on_avatar_loaded():
	avatar.texture = NetworkManager.steam_image
	steam_name.text = NetworkManager.steam_username
	
