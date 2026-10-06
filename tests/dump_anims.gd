extends SceneTree
## Prints what the PMD Sprite Importer extracted for each sprite folder.

func _initialize() -> void:
	for folder in OS.get_cmdline_user_args():
		var s := PMDSpriteImporter.load_sprite_set(folder)
		print("== %s shadow=%d ground=%s anims=%d" % [folder, s.shadow_size, s.ground_offset, s.anims.size()])
		var names := s.anim_names()
		names.sort()
		for n in names:
			var a: PMDAnim = s.anims[n]
			var emit := a.get_emit_point(2)
			print("  %-12s %3dx%-3d f=%-2d rows=%d dur=%.2fs hit=%d(%.2fs) rush=%d ret=%d copy=%s emitR=%s" % [n, a.frame_size.x, a.frame_size.y, a.frame_count(), a.rows, a.duration_seconds(), a.hit_frame, a.hit_time(), a.rush_frame, a.return_frame, a.copy_of, emit])
	quit()
