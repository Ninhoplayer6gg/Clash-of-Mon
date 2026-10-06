extends Node
## Autoload "Game": navigation between screens and the configuration of the
## match about to be played.

const SCREENS := {
	"main_menu": "res://ui/main_menu.tscn",
	"select": "res://ui/select_screen.tscn",
	"pokedex": "res://ui/pokedex_screen.tscn",
	"settings": "res://ui/settings_screen.tscn",
	"credits": "res://ui/credits_screen.tscn",
	"match": "res://core/match.tscn",
}

## Arguments for the next screen (e.g. {"mode": "training"}).
var screen_args := {}
## Match description consumed by core/match.gd.
var match_config := {}
var last_result := {}
## Remembered selections so "JOGAR" again starts where the player left.
var last_selection := {}


func goto(screen: String, args: Dictionary = {}) -> void:
	screen_args = args
	var path: String = SCREENS.get(screen, "")
	if path == "":
		push_error("Unknown screen %s" % screen)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


func start_match(config: Dictionary) -> void:
	match_config = config
	goto("match")


func restart_match() -> void:
	goto("match")


static func make_config(mode: String, player_team: Array, enemy_team: Array, arena: String, training: bool = false, options: Dictionary = {}) -> Dictionary:
	var opts := {
		"infinite_hp": false,
		"instant_cooldown": false,
		"show_hitboxes": false,
		"bot_behavior": "active",  # idle | passive | active
		"bot_difficulty": 1,       # 0 easy, 1 normal, 2 hard
		"mega_enabled": false,
		"time_limit": true,
	}
	for k in options.keys():
		opts[k] = options[k]
	return {
		"mode": mode,
		"training": training,
		"arena": arena,
		"teams": [
			{"members": player_team, "controller": "player"},
			{"members": enemy_team, "controller": "bot"},
		],
		"options": opts,
	}
