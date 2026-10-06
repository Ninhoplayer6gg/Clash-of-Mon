class_name TeamState
extends RefCounted
## One side of a match: up to 3 Pokémon, only one on the field at a time.
## Benched Pokémon keep HP, cooldowns, ult and status-free state; fainted
## Pokémon cannot come back during the round.

var index := 0
var controller := "player"
var members: Array[String] = []
var fighters: Array[Fighter] = []
var active := 0
var switch_cd := 0.0
var color := Color(0.35, 0.7, 1.0)


func active_fighter() -> Fighter:
	if active < 0 or active >= fighters.size():
		return null
	return fighters[active]


func alive_count() -> int:
	var n := 0
	for f in fighters:
		if f.is_alive():
			n += 1
	return n


func is_defeated() -> bool:
	return alive_count() == 0


## Next alive bench index going in `direction` (+1/-1) from the active slot.
func next_available(direction: int = 1) -> int:
	var n := fighters.size()
	for step in range(1, n):
		var i := posmod(active + step * direction, n)
		if fighters[i].is_alive():
			return i
	return -1


func can_switch_to(i: int) -> bool:
	return i >= 0 and i < fighters.size() and i != active and fighters[i].is_alive() and switch_cd <= 0.0
