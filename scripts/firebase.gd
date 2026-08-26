class_name Firebase extends Node
# Optional cloud accounts via the Firebase REST API — no SDK required.
# Drop a config at user://firebase_config.json (or res://firebase_config.json):
#   {"api_key": "<Web API key>", "project_id": "<project id>"}
# and the menu shows email/password sign-in. The player's profile (name +
# appearance) syncs to Firestore at users/{uid}.

var api_key := ""
var project_id := ""
var uid := ""
var id_token := ""
var refresh_token := ""
var email := ""

func _ready() -> void:
	for path in ["user://firebase_config.json", "res://firebase_config.json"]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var cfg: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if cfg is Dictionary:
				api_key = cfg.get("api_key", "")
				project_id = cfg.get("project_id", "")
			break

func configured() -> bool:
	return api_key != "" and project_id != ""

func signed_in() -> bool:
	return uid != "" and id_token != ""

func _request(url: String, method: HTTPClient.Method, body: Dictionary, headers: PackedStringArray = []) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var all_headers := PackedStringArray(["Content-Type: application/json"])
	all_headers.append_array(headers)
	var err := req.request(url, all_headers, method, JSON.stringify(body) if not body.is_empty() else "")
	if err != OK:
		req.queue_free()
		return {"error": {"message": "REQUEST_FAILED"}}
	var result: Array = await req.request_completed
	req.queue_free()
	var response: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if response is Dictionary:
		return response
	return {"error": {"message": "BAD_RESPONSE (HTTP %d)" % result[1]}}

# ---------------------------------------------------------------- auth

func auth_email(mail: String, password: String, register: bool) -> String:
	# Returns "" on success, or a human-readable error.
	var action := "signUp" if register else "signInWithPassword"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s" % [action, api_key]
	var res := await _request(url, HTTPClient.METHOD_POST,
		{"email": mail, "password": password, "returnSecureToken": true})
	if res.has("error"):
		return String(res["error"].get("message", "UNKNOWN")).replace("_", " ").to_lower()
	uid = res.get("localId", "")
	id_token = res.get("idToken", "")
	refresh_token = res.get("refreshToken", "")
	email = mail
	return ""

# ---------------------------------------------------------------- profile sync

func _doc_url() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s" % [project_id, uid]

func push_profile(appearance: Dictionary) -> void:
	if not signed_in():
		return
	var fields := {}
	for k in appearance:
		var v: Variant = appearance[k]
		if v is bool:
			fields[k] = {"booleanValue": v}
		elif v is int:
			fields[k] = {"integerValue": str(v)}
		else:
			fields[k] = {"stringValue": str(v)}
	await _request(_doc_url() + "?" + "&".join(appearance.keys().map(func(k): return "updateMask.fieldPaths=" + k)),
		HTTPClient.METHOD_PATCH, {"fields": fields},
		PackedStringArray(["Authorization: Bearer " + id_token]))

func pull_profile() -> Dictionary:
	# Returns the stored appearance, or {} if none / not signed in.
	if not signed_in():
		return {}
	var res := await _request(_doc_url(), HTTPClient.METHOD_GET, {},
		PackedStringArray(["Authorization: Bearer " + id_token]))
	if not res.has("fields"):
		return {}
	var out := {}
	for k in res["fields"]:
		var fv: Dictionary = res["fields"][k]
		if fv.has("integerValue"):
			out[k] = int(fv["integerValue"])
		elif fv.has("booleanValue"):
			out[k] = bool(fv["booleanValue"])
		elif fv.has("stringValue"):
			out[k] = String(fv["stringValue"])
	return out
