class_name StatusManager
extends RefCounted
## Real-time status effects and timed stat modifiers for one fighter.
##
## Major statuses (data/status.json):
##  burn      - damage over time, weaker physical attacks
##  poison    - stacking damage over time
##  paralysis - slower movement/attacks + a tiny jolt on application
##  freeze    - short full stop, broken by the next hit (bonus damage)
##  sleep     - short full stop, broken by any damage
## Hard control (freeze/sleep) grants temporary immunity afterwards so the
## player is never locked for long.

signal status_applied(id: String)
signal status_removed(id: String)

const HARD_CC := ["freeze", "sleep"]
## Canon type immunities (Fire can't burn, Electric can't be paralysed...).
const TYPE_IMMUNE := {
	"burn": ["fire"],
	"paralysis": ["electric"],
	"freeze": ["ice"],
	"poison": ["poison", "steel"],
}

var fighter: Fighter
var effects := {}    # id -> {time, max, stacks, tick, source}
var immunity := {}   # id -> seconds left
var mods: Array = [] # [{id, time, ...multipliers}]
var jolt := 0.0
var _freeze_shatter := false


func _init(p_fighter: Fighter) -> void:
	fighter = p_fighter


func apply(id: String, source: Fighter = null, duration: float = -1.0) -> bool:
	var def := GameData.status_def(id)
	if def.is_empty():
		return false
	if immunity.get(id, 0.0) > 0.0:
		return false
	for t in TYPE_IMMUNE.get(id, []):
		if fighter.types.has(t):
			return false
	if fighter.passive and not fighter.passive.allow_status(id, source):
		return false
	var dur: float = duration if duration > 0.0 else float(def.get("duration", 1.0))
	var e: Dictionary = effects.get(id, {})
	var is_new := e.is_empty()
	if is_new:
		e = {"time": dur, "max": dur, "stacks": 1, "tick": float(def.get("tick", 0.5)), "source": source}
		effects[id] = e
	else:
		e["time"] = maxf(e["time"], dur)
		e["max"] = maxf(e["max"], dur)
		e["stacks"] = mini(int(e["stacks"]) + 1, int(def.get("max_stacks", 1)))
		e["source"] = source
	match id:
		"paralysis":
			if is_new:
				jolt = maxf(jolt, float(def.get("jolt_stun", 0.15)))
		"freeze", "sleep":
			fighter.on_hard_cc()
	if is_new:
		status_applied.emit(id)
	return true


func has(id: String) -> bool:
	return effects.has(id)


func stacks(id: String) -> int:
	return int(effects.get(id, {}).get("stacks", 0))


func remove(id: String) -> void:
	if not effects.has(id):
		return
	effects.erase(id)
	var def := GameData.status_def(id)
	if HARD_CC.has(id):
		immunity[id] = float(def.get("immunity", 3.0))
	status_removed.emit(id)


func clear_all(include_mods: bool = false) -> void:
	for id in effects.keys():
		remove(id)
	jolt = 0.0
	if include_mods:
		mods.clear()


func cleanse(ids: Array) -> void:
	for id in ids:
		remove(id)


func update(delta: float) -> void:
	if jolt > 0.0:
		jolt -= delta
	for id in immunity.keys():
		immunity[id] -= delta
		if immunity[id] <= 0.0:
			immunity.erase(id)
	for id in effects.keys():
		# A DoT tick can faint the fighter and clear every effect mid-loop.
		if not effects.has(id):
			continue
		var e: Dictionary = effects[id]
		e["time"] -= delta
		var def := GameData.status_def(id)
		var dps_pct := float(def.get("dps_max_hp_pct", 0.0))
		if dps_pct > 0.0:
			e["tick"] -= delta
			if e["tick"] <= 0.0:
				var interval := float(def.get("tick", 0.5))
				e["tick"] += interval
				var amount := fighter.max_hp * dps_pct * interval * int(e["stacks"])
				fighter.take_dot(int(round(amount)), e["source"], id)
				if not effects.has(id):
					continue
		if e["time"] <= 0.0:
			remove(id)
	var i := mods.size() - 1
	while i >= 0:
		var m: Dictionary = mods[i]
		m["time"] -= delta
		if m["time"] <= 0.0:
			mods.remove_at(i)
		i -= 1


# ---------------------------------------------------------------- modifiers

func add_mod(id: String, duration: float, params: Dictionary) -> void:
	for m in mods:
		if m["id"] == id:
			m["time"] = duration
			return
	var m := params.duplicate()
	m["id"] = id
	m["time"] = duration
	mods.append(m)


func remove_mod(id: String) -> void:
	for i in range(mods.size() - 1, -1, -1):
		if mods[i]["id"] == id:
			mods.remove_at(i)


func has_mod(id: String) -> bool:
	for m in mods:
		if m["id"] == id:
			return true
	return false


func _mods_product(key: String) -> float:
	var v := 1.0
	for m in mods:
		v *= float(m.get(key, 1.0))
	return v


func _mods_any(key: String) -> bool:
	for m in mods:
		if m.get(key, false):
			return true
	return false


# ------------------------------------------------------------------ queries

func is_disabled() -> bool:
	return jolt > 0.0 or effects.has("freeze") or effects.has("sleep")


func is_frozen() -> bool:
	return effects.has("freeze")


func is_asleep() -> bool:
	return effects.has("sleep")


func speed_mult() -> float:
	var v := _mods_product("speed_mult")
	for id in effects.keys():
		v *= float(GameData.status_def(id).get("speed_mult", 1.0))
	return v


func attack_speed_mult() -> float:
	var v := _mods_product("attack_speed_mult")
	if effects.has("paralysis"):
		v *= float(GameData.status_def("paralysis").get("attack_speed_mult", 1.0))
	return v


func knockback_mult() -> float:
	return _mods_product("knockback_mult")


func has_super_armor() -> bool:
	return _mods_any("super_armor")


func outgoing_mult(info: DamageInfo) -> float:
	var v := _mods_product("damage_mult")
	if info.category == "physical" and effects.has("burn"):
		v *= float(GameData.status_def("burn").get("physical_damage_mult", 1.0))
	return v


func incoming_mult(info: DamageInfo) -> float:
	var v := _mods_product("damage_taken_mult")
	if effects.has("vulnerable"):
		v *= float(GameData.status_def("vulnerable").get("damage_taken_mult", 1.0))
	if effects.has("freeze") and not info.is_dot:
		v *= float(GameData.status_def("freeze").get("break_bonus_damage", 1.0))
	return v


## Called after a direct hit lands: breaks sleep and freeze.
func on_damaged(info: DamageInfo) -> void:
	if info.is_dot:
		return
	if effects.has("sleep"):
		remove("sleep")
	if effects.has("freeze"):
		remove("freeze")


func tint() -> Color:
	if effects.has("freeze"):
		return Color(0.65, 0.9, 1.15)
	if effects.has("sleep"):
		return Color(0.75, 0.75, 1.0)
	if effects.has("paralysis") and int(Time.get_ticks_msec() / 90) % 3 == 0:
		return Color(1.25, 1.2, 0.5)
	if effects.has("burn"):
		return Color(1.15, 0.85, 0.75)
	if effects.has("poison"):
		return Color(1.0, 0.8, 1.1)
	return Color.WHITE


const _VISIBLE_ORDER := ["burn", "poison", "paralysis", "freeze", "sleep", "slow", "vulnerable"]
var _visible: Array = []


## Ordered list of visible status ids (for HUD chips). The returned array is
## reused between calls: read it, don't keep it.
func visible_ids() -> Array:
	_visible.clear()
	for id in _VISIBLE_ORDER:
		if effects.has(id):
			_visible.append(id)
	return _visible
