extends RefCounted
## Display names only. Save paths, web storage keys and project identity stay stable.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/brand.json"))

static func text(key: String, locale: String) -> String:
	return str(data.get(locale, data.en).get(key, ""))
