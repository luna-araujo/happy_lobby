class_name MainMenuVersionLabel
extends Label

@export var prefix: String = "Version "
@export var fallback_version: String = "dev"


func _ready() -> void:
	var version_value: Variant = ProjectSettings.get_setting("application/config/version", fallback_version)
	var resolved_version: String = String(version_value).strip_edges()
	if resolved_version.is_empty():
		resolved_version = fallback_version
	text = "%s%s" % [prefix, resolved_version]
