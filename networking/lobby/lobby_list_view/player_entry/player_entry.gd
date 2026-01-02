class_name PlayerEntry
extends HBoxContainer

var avatar_rect: TextureRect
var name_label: Label
var ping_label: Label

var steam_id: int

func _ready() -> void:
	avatar_rect = $Avatar
	name_label = $Name
	ping_label = $Ping

	Steam.avatar_loaded.connect(_on_loaded_avatar)



static func new_entry(steam_id: int) -> PlayerEntry:
	var instance = ResourceLoader.load("res://networking/lobby/lobby_list_view/player_entry/player_entry.tscn").instantiate() as PlayerEntry
	instance.setup(steam_id)
	return instance

func setup(steam_id: int) -> void:
	self.steam_id = steam_id
	Steam.getPlayerAvatar(2, steam_id)

func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if user_id != steam_id: return
	
	print("Avatar for local user: %s" % user_id)
	print("Size: %s" % avatar_size)

	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)

	# Optionally resize the image if it is too large
	#if avatar_size > 128:
		#avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	# Apply the image to a texture
	avatar_rect.texture = ImageTexture.create_from_image(avatar_image)

	name_label.text = Steam.getPlayerNickname(steam_id)
	ping_label.text = ""
