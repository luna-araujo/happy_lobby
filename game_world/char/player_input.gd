class_name PlayerInput
extends MultiplayerSynchronizer

var direction: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	direction = Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	
	direction = direction.normalized()

