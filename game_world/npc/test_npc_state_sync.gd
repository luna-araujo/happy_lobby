class_name TestNpcStateSync
extends MultiplayerSynchronizer

@export var npc_root_path: NodePath = NodePath("..")


func _ready() -> void:
	root_path = npc_root_path
	replication_config = _build_replication_config()


func _build_replication_config() -> SceneReplicationConfig:
	var config: SceneReplicationConfig = SceneReplicationConfig.new()

	_add_property(config, NodePath(":global_position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath(":global_rotation"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath(":velocity"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_property(config, NodePath(":npc_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":display_name"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath("CharacterCombat:hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath("CharacterCombat:max_hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath("CharacterCombat:state"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_inventory_slots_json"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_property(config, NodePath(":network_inventory_money"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	return config


func _add_property(config: SceneReplicationConfig, property_path: NodePath, replication_mode: int) -> void:
	config.add_property(property_path)
	config.property_set_spawn(property_path, true)
	config.property_set_replication_mode(property_path, replication_mode)
