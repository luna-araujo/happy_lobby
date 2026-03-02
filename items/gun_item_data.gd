class_name GunItemData
extends ItemData

@export var equipped_item_id: StringName = &""
@export var weapon_scene: PackedScene

@export var local_position: Vector3 = Vector3.ZERO
@export var local_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var local_scale: Vector3 = Vector3(2.5, 2.5, 2.5)

@export var fire_damage: int = 6
@export var fire_rate_per_second: float = 6.0
@export var max_shoot_distance: float = 180.0

@export var hand_override_forward_distance: float = 0.75
@export var hand_override_right_offset: float = 0.35
@export var hand_override_vertical_offset: float = 1.35
@export var hand_override_look_offset_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)

@export var gun_shoot_sfx: AudioStream
@export var gun_impact_sfx: AudioStream
@export var gun_hit_vfx_scene: PackedScene
@export var gun_feedback_volume_db: float = -6.0
