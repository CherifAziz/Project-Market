extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for cycle in range(5):
		var scene := Node3D.new()
		root.add_child(scene)
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.current = true
		var audio := AudioService.new()
		scene.add_child(audio)
		for _shot in range(3):
			audio.play_world(&"smg", Vector3(0, 0, -2))
		audio.play_ui(&"run_settled")
		await create_timer(0.025, true, false, true).timeout
		var probes := SceneCleanup.audio_probes(scene)
		if not SceneCleanup.has_live_references(probes):
			_failed = true
			push_error("FAIL: audio fixture must really allocate streams/playbacks")
		if not await SceneCleanup.free_scene(self, scene):
			_failed = true
			push_error("FAIL: audio resources remained alive after explicit teardown")
		elif SceneCleanup.has_live_references(probes):
			_failed = true
			push_error("FAIL: a playback/stream/node survived shutdown")
		else:
			print("PASS: actual WAV/playback/node references released after active-audio teardown cycle ", cycle + 1)
	print("Audio lifecycle test complete.")
	quit(1 if _failed else 0)
