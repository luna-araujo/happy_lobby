class_name ItemData
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("common", "uncommon", "rare", "epic", "legendary") var rarity: String = "common"
@export var icon: Texture2D
@export var max_stack: int = 99
@export var tags: PackedStringArray = PackedStringArray()
