class_name CharacterMovement
extends Node

var character: Character = null
var speed: int = 200
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	character = get_parent() as Character

func _process(delta: float) -> void:
	if character == null || character.input == null:
		return
	
	if !multiplayer.is_server():
		return

	# Authority client: read input and move
	velocity = character.input.direction * speed
	character.velocity = velocity
	character.move_and_slide()
	
	# Sync position to all clients via RPC
	_sync_position.rpc(character.global_position)


@rpc("authority", "call_remote", "unreliable")
func _sync_position(position: Vector2) -> void:
	# All clients (including authority) update the character position
	if character:
		character.global_position = position
