class_name CreditsDB
extends RefCounted
## Reads SpriteCollab credit data shipped with the assets
## (credits.txt per sprite/portrait folder + credit_names.txt) so in-game
## credits always match the files actually used.

const NAMES_PATH := "res://assets/pmd/credit_names.txt"
const LICENSE_LABELS := {
	"Unspecified": "Oficial (Spike Chunsoft) — sem licença CC; uso de fã não-comercial",
	"PMDCollab_1": "Licença PMDCollab 1 (uso/modificação com crédito)",
	"PMDCollab_2": "Licença PMDCollab 2 (com crédito, sem fins lucrativos)",
	"CC_BY-NC_4": "CC BY-NC 4.0",
}

static var _names := {}


static func artist_name(id: String) -> String:
	if _names.is_empty():
		_load_names()
	if id == "CHUNSOFT":
		return "Spike Chunsoft (oficial)"
	var e: Dictionary = _names.get(id, {})
	return String(e.get("name", id))


static func artist_contact(id: String) -> String:
	if _names.is_empty():
		_load_names()
	return String(_names.get(id, {}).get("contact", ""))


static func _load_names() -> void:
	_names["_loaded"] = {}
	if not FileAccess.file_exists(NAMES_PATH):
		return
	var f := FileAccess.open(NAMES_PATH, FileAccess.READ)
	while not f.eof_reached():
		var cols := f.get_line().split("\t")
		if cols.size() < 2 or cols[0] == "Name":
			continue
		_names[cols[1]] = {"name": cols[0], "contact": cols[2] if cols.size() > 2 else ""}


## Credits rows (only current "CUR" entries) for a sprite or portrait folder.
static func folder_credits(folder: String) -> Array:
	var rows := PMDSpriteImporter.parse_credits(folder.trim_suffix("/") + "/credits.txt")
	var out := []
	for r in rows:
		if r["status"] == "CUR":
			out.append(r)
	return out


## Human readable BBCode summary of the credits of a folder.
static func summary_bbcode(folder: String, used_anims: PackedStringArray = PackedStringArray()) -> String:
	var lines := PackedStringArray()
	for r in folder_credits(folder):
		var anims: PackedStringArray = r["anims"]
		var shown := anims
		if not used_anims.is_empty():
			shown = PackedStringArray()
			for a in anims:
				if used_anims.has(a):
					shown.append(a)
			if shown.is_empty():
				continue
		var who := artist_name(r["author"])
		var lic := String(LICENSE_LABELS.get(r["license"], r["license"]))
		var tag := "[color=#ffd23f]OFICIAL[/color]" if r["official"] else "[color=#7fe0a0]COMUNIDADE[/color]"
		lines.append("%s [b]%s[/b] — %s\n   [color=#9aa6b8]%s[/color]" % [tag, who, lic, ", ".join(shown)])
	return "\n".join(lines)
