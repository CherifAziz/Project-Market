class_name SceneCleanup
extends RefCounted

static func free_scene(tree: SceneTree, scene: Node) -> bool:
	# AudioServer retires stopped playbacks on its mixer thread. Two render frames
	# are not a lifetime guarantee, especially with the headless Dummy driver.
	# Observe actual resource release; never disable audio or hide leak warnings.
	var probes := audio_probes(scene)
	probes.append(weakref(scene))
	scene.queue_free()
	var deadline := Time.get_ticks_msec() + 1500
	while has_live_references(probes) and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.01, true, false, true).timeout
	return not has_live_references(probes)

static func audio_probes(scene: Node) -> Array[WeakRef]:
	var probes: Array[WeakRef] = []
	for node in scene.find_children("*", "", true, false):
		if node is AudioService:
			for stream in node._streams.values():
				probes.append(weakref(stream))
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			probes.append(weakref(node))
			if node.stream != null:
				probes.append(weakref(node.stream))
			if node.has_stream_playback():
				probes.append(weakref(node.get_stream_playback()))
	return probes

static func has_live_references(probes: Array[WeakRef]) -> bool:
	return probes.any(func(probe: WeakRef) -> bool: return probe.get_ref() != null)
