class_name Lobby
extends Node

const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false

func _init() -> void:
	#Steam.join_requested.connect(_on_lobby_join_requested)
	#Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	#Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	#Steam.lobby_match_list.connect(_on_lobby_match_list)
	#Steam.lobby_message.connect(_on_lobby_message)
	#Steam.persona_state_change.connect(_on_persona_change)

	# Check for command line arguments
	check_command_line()


func join_lobby(this_lobby_id: int) -> void:
	print("Attempting to join lobby %s" % lobby_id)

	# Clear any previous lobby members lists, if you were in a previous lobby
	lobby_members.clear()

	# Make the lobby join request to Steam
	Steam.joinLobby(this_lobby_id)


func create_lobby() -> void:
	# Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

func _on_lobby_joined( lobby: int, permissions: int, locked: bool, response: int ) -> void:
	# Set the lobby ID
	lobby_id = lobby
	print("Joined a lobby: %s" % lobby_id)

	# Retrieve lobby data
	lobby_data = Steam.getAllLobbyData(lobby_id)
	print("Lobby Data: %s" % lobby_data)

	# Get the current members of the lobby
	var num_members: int = Steam.getNumLobbyMembers(lobby_id)
	for i in range(num_members):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		lobby_members.append(member_steam_id)
		print("Lobby Member %s: %s" % [i, member_steam_id])

func _on_lobby_created(_connect: int, this_lobby_id: int) -> void:
	if _connect == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)

		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)

		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % NetworkManager.steam_username)
		Steam.setLobbyData(lobby_id, "game", "happy_lobby")

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)

func get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("game", "happy_lobby", Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)

	print("Requesting a lobby list")
	Steam.requestLobbyList()


 
func check_command_line() -> void:
	var these_arguments: Array = OS.get_cmdline_args()

	# There are arguments to process
	if these_arguments.size() > 0:
		# A Steam connection argument exists
		if these_arguments[0] == "+connect_lobby":
			# Lobby invite exists so try to connect to it
			if int(these_arguments[1]) > 0:
				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				print("Command line lobby ID: %s" % these_arguments[1])
				join_lobby(int(these_arguments[1]))
