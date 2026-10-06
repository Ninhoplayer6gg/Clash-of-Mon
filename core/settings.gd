extends Node
## Autoload "Settings": user preferences persisted in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2

var target_fps := 60
var quality := QUALITY_MEDIUM
var show_fps := false
var debug_overlay := false
var show_hitboxes := false
var controls_scale := 1.0
var controls_opacity := 0.8
var aim_assist := true
var screen_shake := true
var vibration := true
var damage_numbers := true
var sfx_volume := 0.8
## "auto" shows touch controls on touch devices only; "on"/"off" force it.
var touch_controls := "auto"

const _KEYS := [
	"target_fps", "quality", "show_fps", "debug_overlay", "show_hitboxes",
	"controls_scale", "controls_opacity", "aim_assist", "screen_shake",
	"vibration", "damage_numbers", "sfx_volume", "touch_controls",
]


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		# Weak-device friendly defaults on mobile.
		if OS.has_feature("mobile"):
			quality = QUALITY_MEDIUM
		return
	for k in _KEYS:
		if cfg.has_section_key("settings", k):
			set(k, cfg.get_value("settings", k))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in _KEYS:
		cfg.set_value("settings", k, get(k))
	cfg.save(PATH)


func apply() -> void:
	Engine.max_fps = target_fps
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, sfx_volume <= 0.001)
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()


func max_particles() -> int:
	match quality:
		QUALITY_LOW: return 70
		QUALITY_HIGH: return 320
	return 160


func particle_scale() -> float:
	match quality:
		QUALITY_LOW: return 0.4
		QUALITY_HIGH: return 1.0
	return 0.7


func use_touch_controls() -> bool:
	if touch_controls == "on":
		return true
	if touch_controls == "off":
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
