#Singleton -> NetworkManager
extends Node

signal steam_started()
signal avatar_loaded()

const STEAM_CONFIG_SCRIPT: Script = preload("res://networking/steam_config.gd")
const APP_ID = 480 #Spacewar
const LOCAL_USER_ID: String = "user://local_user_id"

var using_steam: bool = false
var app_installed_depots: Array
var app_languages: String
var app_owner: int
var build_id: int
var game_language: String
var install_dir: String
var is_on_steam_deck: bool
var is_on_vr: bool
var is_online: bool
var is_owned: bool
var launch_command_line: String
var steam_id: int
var steam_username: String
var steam_image: ImageTexture
var ui_language: String


var lobby: Lobby = Lobby.new()

func _init() -> void:
	using_steam = STEAM_CONFIG_SCRIPT.is_enabled()

	add_child(lobby)

	if not using_steam:
		print("Steam is not available.")
		steam_id = get_local_user_id()
		steam_username = get_user_os_username()
		steam_image = null
		ui_language = OS.get_locale()
		steam_started.emit()
		return

	var initialize_response: Dictionary = Steam.steamInitEx( APP_ID, true )
	print("Did Steam initialize?: %s " % initialize_response)
	
	app_installed_depots = Steam.getInstalledDepots( APP_ID )
	app_languages = Steam.getAvailableGameLanguages()
	app_owner = Steam.getAppOwner()
	build_id = Steam.getAppBuildId()
	game_language = Steam.getCurrentGameLanguage()
	install_dir = Steam.getAppInstallDir( APP_ID )
	is_on_steam_deck = Steam.isSteamRunningOnSteamDeck()
	is_on_vr = Steam.isSteamRunningInVR()
	is_online = Steam.loggedOn()
	is_owned = Steam.isSubscribed()
	launch_command_line = Steam.getLaunchCommandLine()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	steam_image = null
	ui_language = Steam.getSteamUILanguage()
	
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	Steam.getPlayerAvatar(2, steam_id)

	steam_started.emit()


func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if user_id != steam_id: return
	if steam_image != null: return
	
	print("Avatar for local user: %s" % user_id)
	print("Size: %s" % avatar_size)

	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	steam_image = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit()

func get_local_user_id() -> int:
	var file = FileAccess.open(LOCAL_USER_ID, FileAccess.READ)
	if file == null:
		var new_id: int = randi()
		var write_file = FileAccess.open(LOCAL_USER_ID, FileAccess.WRITE)
		write_file.store_32(new_id)
		write_file.close()
		return new_id
	else:
		var existing_id: int = file.get_32()
		file.close()
		return existing_id

func get_user_os_username() -> String:
	var username = ""
	# Check for the 'USER' environment variable (common on Linux, macOS, Android)
	if OS.has_environment("USER"):
		username = OS.get_environment("USER")
	# Check for the 'USERNAME' environment variable (common on Windows)
	elif OS.has_environment("USERNAME"):
		username = OS.get_environment("USERNAME")
	return username

func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")

	# send_p2p_packet(0, {"message": "handshake", "from": steam_id})
