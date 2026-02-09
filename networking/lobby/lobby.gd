class_name Lobby
extends Node

const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false

func _ready() -> void:
	if NetworkManager.using_steam:
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


func join_steam_lobby(this_lobby_id: int) -> void:
	if NetworkManager:
		print("Attempting to join lobby %s" % this_lobby_id)
		lobby_members.clear()
		Steam.joinLobby(this_lobby_id)


func create_lobby() -> void:
	# Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
		# If joining was successful
		if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
			lobby_id = this_lobby_id
			get_lobby_members()
			var owner_id := Steam.getLobbyOwner(this_lobby_id)
			if owner_id == NetworkManager.steam_id:
				if !multiplayer.is_server():
					SessionManager.create_steam_host(this_lobby_id)
				return
			SessionManager.join_steam_lobby(this_lobby_id)
		else:
			var fail_reason: String

			match response:
				Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
				Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
				Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
				Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
				Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
				Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
				Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
				Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
				Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
				Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."

			print("Failed to join this chat room: %s" % fail_reason)


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

		SessionManager.create_steam_host(lobby_id)

func get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("game", "happy_lobby", Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)

	print("Requesting a lobby list")
	Steam.requestLobbyList()


func get_lobby_members() -> void:
	lobby_members.clear()

	if NetworkManager.using_steam:
		var num_of_members: int = Steam.getNumLobbyMembers(lobby_id)

		for this_member in range(0, num_of_members):
			var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, this_member)
			var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
			lobby_members.append({"steam_id":member_steam_id, "steam_name":member_steam_name})
		


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
				join_steam_lobby(int(these_arguments[1]))
