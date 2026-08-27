class_name Profile
# The player's identity: display name + appearance + (optional) cloud auth.
# Lives at user://profile.json, loads before the menu, follows you into
# every world. When Firebase is configured and signed in, the same data
# syncs to Firestore so your identity travels between machines.

const PATH := "user://profile.json"
const PROFILE_VERSION := 1

const HAIR_STYLES := ["short", "long", "bald"]

static func defaults() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {
		"name": "survivor",
		"skin": rng.randi_range(0, 4),
		"hair_color": rng.randi_range(0, 5),
		"hair_style": 0,
		"beard": rng.randi_range(0, 2) == 0,
		"shirt": rng.randi_range(0, 7),
		"auth": {},
	}

static func load_profile() -> Dictionary:
	var p := defaults()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Dictionary:
			for k in data:
				p[k] = data[k]
	return p

static func save_profile(p: Dictionary) -> void:
	p["profile_version"] = PROFILE_VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(p))
	f.close()

# The subset that other players see (and that syncs to the cloud).
static func appearance_of(p: Dictionary) -> Dictionary:
	return {
		"name": String(p.get("name", "survivor")).substr(0, 20),
		"skin": int(p.get("skin", 0)),
		"hair_color": int(p.get("hair_color", 0)),
		"hair_style": int(p.get("hair_style", 0)),
		"beard": bool(p.get("beard", false)),
		"shirt": int(p.get("shirt", 0)),
	}
