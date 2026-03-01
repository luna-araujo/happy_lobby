class_name AvatarStateSync
extends MultiplayerSynchronizer

@export var avatar_path: NodePath = NodePath("..")


func _ready() -> void:
	root_path = avatar_path
	replication_config = _build_replication_config()


func _build_replication_config() -> SceneReplicationConfig:
	var config := SceneReplicationConfig.new()

	# Movement replication.
	_add_property(config, NodePath("Armature:global_position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath("Armature:global_rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath("Armature:velocity"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	# Animation and combat replication.
	_add_property(config, NodePath(":network_animation_state"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_move_speed"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath(":network_combat_state"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_max_hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_display_name"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	return config


func _add_property(config: SceneReplicationConfig, property_path: NodePath, replication_mode: int) -> void:
	config.add_property(property_path)
	config.property_set_spawn(property_path, true)
	config.property_set_replication_mode(property_path, replication_mode)
