extends SceneTree
## Loads every script and scene in the project to surface parse errors.

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var failed := 0
	var count := 0
	for path in _collect("res://"):
		count += 1
		var res = load(path)
		if res == null:
			failed += 1
			print("FAILED: ", path)
		elif res is GDScript and not res.can_instantiate():
			failed += 1
			print("CANNOT INSTANTIATE: ", path)
	print("CHECK: %d files, %d failed" % [count, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "assets" or sub == "addons":
			continue
		out.append_array(_collect(dir.path_join(sub)))
	return out
