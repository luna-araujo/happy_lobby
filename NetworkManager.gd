#Singleton -> NetworkManager
extends Node

const APP_ID = 480 #Spacewar

var app_installed_depots: Array = Steam.getInstalledDepots( APP_ID )
var app_languages: String = Steam.getAvailableGameLanguages()
var app_owner: int = Steam.getAppOwner()
var build_id: int = Steam.getAppBuildId()
var game_language: String = Steam.getCurrentGameLanguage()
var install_dir: String = Steam.getAppInstallDir( APP_ID )
var is_on_steam_deck: bool = Steam.isSteamRunningOnSteamDeck()
var is_on_vr: bool = Steam.isSteamRunningInVR()
var is_online: bool = Steam.loggedOn()
var is_owned: bool = Steam.isSubscribed()
var launch_command_line: String = Steam.getLaunchCommandLine()
var steam_id: int = Steam.getSteamID()
var steam_username: String = Steam.getPersonaName()
var ui_language: String = Steam.getSteamUILanguage()

func _init() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx( APP_ID, true )
	print("Did Steam initialize?: %s " % initialize_response)
