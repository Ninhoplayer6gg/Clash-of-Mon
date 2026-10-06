class_name PMDSpriteSet
extends RefCounted
## All animations of one SpriteCollab sprite folder (one Pokémon form).

## Shadow size from AnimData.xml (0 small, 1 medium, 2 large).
var shadow_size := 1
var folder := ""
## Ground point relative to the frame centre (PMD draws the shadow slightly
## below the frame centre). Read from *-Shadow.png when present.
var ground_offset := Vector2(0, 4)
var anims := {}  # String -> PMDAnim
var credits: Array = []  # Array of Dictionary rows parsed from credits.txt


func has_anim(anim_name: String) -> bool:
	return anims.has(anim_name)


func get_anim(anim_name: String) -> PMDAnim:
	return anims.get(anim_name)


func anim_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in anims.keys():
		out.append(k)
	return out


## Approximate body height in pixels (from the Idle sheet), used for HP bars
## and hurtbox heights.
func body_height() -> float:
	var idle: PMDAnim = anims.get("Idle")
	if idle == null:
		return 24.0
	var head := idle.get_point(0, 0, PMDAnim.Point.HEAD)
	if head == Vector2.INF:
		return idle.frame_size.y * 0.5
	return absf(head.y - ground_offset.y) + 6.0
