class_name SteamConfig
extends RefCounted

const DEFAULT_ENABLED: bool = false
const ENV_NAME: String = "HAPPY_LOBBY_STEAM"
const RELEASE_FEATURE_NAME: String = "steam"

static func is_enabled() -> bool:
	if OS.has_feature(RELEASE_FEATURE_NAME):
		return true

	if OS.has_environment(ENV_NAME):
		var env_value: String = OS.get_environment(ENV_NAME)
		var parsed_value: Variant = _parse_bool(env_value)
		if parsed_value is bool:
			return parsed_value

	return DEFAULT_ENABLED


static func source_label() -> String:
	if OS.has_feature(RELEASE_FEATURE_NAME):
		return "feature:%s" % RELEASE_FEATURE_NAME

	if OS.has_environment(ENV_NAME):
		var env_value: String = OS.get_environment(ENV_NAME)
		var parsed_value: Variant = _parse_bool(env_value)
		if parsed_value is bool:
			return "env:%s=%s" % [ENV_NAME, env_value]

	return "default:%s" % DEFAULT_ENABLED


static func _parse_bool(value: String) -> Variant:
	var normalized: String = value.strip_edges().to_lower()
	if normalized in ["1", "true", "yes", "on"]:
		return true
	if normalized in ["0", "false", "no", "off"]:
		return false
	return null
