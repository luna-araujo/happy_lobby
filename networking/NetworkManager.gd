#Singleton -> NetworkManager
extends Node

signal avatar_loaded()

const APP_ID = 480 #Spacewar

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

var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()

var lobby:Lobby = Lobby.new()

func _ready():
	if !using_steam:
		return
	pass


func _init() -> void:
	add_child(lobby)

	if !using_steam:
		print("Steam is not available.")
		steam_id = RandomNumberGenerator.new().randi()
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
	
	Steam.lobby_joined.connect(_on_lobby_joined)

	Steam.avatar_loaded.connect(_on_loaded_avatar)
	Steam.getPlayerAvatar(2, steam_id)


func _on_lobby_joined( lobby: int, permissions: int, locked: bool, response: int ) -> void:
	LobbyWindow.create_window(get_tree())

func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if user_id != steam_id: return
	if steam_image != null: return
	
	print("Avatar for local user: %s" % user_id)
	print("Size: %s" % avatar_size)

	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	steam_image = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit()
