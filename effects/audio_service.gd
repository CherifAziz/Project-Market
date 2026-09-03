class_name AudioService
extends Node

const CUE_SMG := &"smg"
const CUE_METAL_IMPACT := &"metal_impact"
const CUE_MACHINE_DAMAGED := &"machine_damaged"
const CUE_MACHINE_DESTROYED := &"machine_destroyed"
const CUE_MARKET_CONFIRM := &"market_confirm"
const CUE_MARKET_DROP := &"market_drop"
const CUE_PROFIT_TICK := &"profit_tick"
const CUE_PROFIT_FINAL := &"profit_final"
const CUE_SECURITY_SHOT := &"security_shot"
const CUE_SECURITY_ALERT := &"security_alert"
const CUE_PLAYER_HIT := &"player_hit"
const CUE_EXTRACTION_START := &"extraction_start"
const CUE_RUN_SETTLED := &"run_settled"

const MIX_RATE := 22050
const WORLD_POOL_SIZE := 14
const UI_POOL_SIZE := 5

@export_group("Mix")
@export_range(-24.0, 12.0, 0.5) var world_volume_offset_db := 0.0
@export_range(-24.0, 12.0, 0.5) var ui_volume_offset_db := 0.0

var _streams: Dictionary = {}
var _base_volumes: Dictionary = {}
var _world_players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _world_cursor := 0
var _ui_cursor := 0
var _noise := RandomNumberGenerator.new()
var _pitch_rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("audio_service")
	_noise.seed = 0x56495441
	_pitch_rng.randomize()
	_build_cues()
	_build_player_pools()

func _exit_tree() -> void:
	for player in _world_players:
		player.stop()
		player.stream = null
	for player in _ui_players:
		player.stop()
		player.stream = null
	_streams.clear()

func has_cue(cue: StringName) -> bool:
	return _streams.has(cue)

func play_world(cue: StringName, position: Vector3, pitch_variation := 0.0, volume_offset_db := 0.0) -> bool:
	if not _streams.has(cue):
		return false
	var player := _next_world_player()
	player.global_position = position
	player.stream = _streams[cue]
	player.volume_db = float(_base_volumes.get(cue, -12.0)) + world_volume_offset_db + volume_offset_db
	player.pitch_scale = 1.0 + _pitch_rng.randf_range(-pitch_variation, pitch_variation)
	player.play()
	return true

func play_ui(cue: StringName, pitch_variation := 0.0, volume_offset_db := 0.0) -> bool:
	if not _streams.has(cue):
		return false
	var player := _next_ui_player()
	player.stream = _streams[cue]
	player.volume_db = float(_base_volumes.get(cue, -12.0)) + ui_volume_offset_db + volume_offset_db
	player.pitch_scale = 1.0 + _pitch_rng.randf_range(-pitch_variation, pitch_variation)
	player.play()
	return true

func _build_cues() -> void:
	_add_cue(CUE_SMG, 0.085, -11.5)
	_add_cue(CUE_METAL_IMPACT, 0.12, -16.0)
	_add_cue(CUE_MACHINE_DAMAGED, 0.34, -10.0)
	_add_cue(CUE_MACHINE_DESTROYED, 0.58, -7.5)
	_add_cue(CUE_MARKET_CONFIRM, 0.28, -12.0)
	_add_cue(CUE_MARKET_DROP, 0.38, -11.0)
	_add_cue(CUE_PROFIT_TICK, 0.3, -12.0)
	_add_cue(CUE_PROFIT_FINAL, 0.72, -8.5)
	_add_cue(CUE_SECURITY_SHOT, 0.11, -10.5)
	_add_cue(CUE_SECURITY_ALERT, 0.52, -9.0)
	_add_cue(CUE_PLAYER_HIT, 0.2, -9.5)
	_add_cue(CUE_EXTRACTION_START, 0.4, -13.0)
	_add_cue(CUE_RUN_SETTLED, 1.15, -9.0)

func _add_cue(cue: StringName, duration: float, volume_db: float) -> void:
	_streams[cue] = _synthesize(cue, duration)
	_base_volumes[cue] = volume_db

func _synthesize(cue: StringName, duration: float) -> AudioStreamWAV:
	var sample_count := maxi(int(duration * MIX_RATE), 1)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(MIX_RATE)
		var sample := _sample_cue(cue, time, duration)
		var encoded := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(sample_index * 2, encoded)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream

func _sample_cue(cue: StringName, time: float, duration: float) -> float:
	var progress := clampf(time / duration, 0.0, 1.0)
	var noise_sample := _noise.randf_range(-1.0, 1.0)
	match cue:
		CUE_SMG:
			var crack := noise_sample * exp(-time * 58.0)
			var body := sin(TAU * 92.0 * time) * exp(-time * 34.0)
			var mechanism := sin(TAU * 720.0 * time) * exp(-time * 55.0)
			return (crack * 0.52 + body * 0.7 + mechanism * 0.15) * _attack(time, 0.0015)
		CUE_METAL_IMPACT:
			var ring := sin(TAU * 1280.0 * time) + sin(TAU * 1860.0 * time) * 0.48
			return (ring * 0.32 + noise_sample * 0.22) * exp(-time * 27.0) * _attack(time, 0.001)
		CUE_MACHINE_DAMAGED:
			var alarm := sin(TAU * (410.0 - progress * 85.0) * time)
			var knock := sin(TAU * 118.0 * time) * exp(-time * 18.0)
			return (alarm * 0.38 + knock * 0.48 + noise_sample * 0.1) * _soft_release(progress)
		CUE_MACHINE_DESTROYED:
			var boom := sin(TAU * (92.0 - progress * 38.0) * time) * exp(-time * 6.0)
			var metal := (sin(TAU * 690.0 * time) + sin(TAU * 970.0 * time) * 0.5) * exp(-time * 9.0)
			return (boom * 0.72 + metal * 0.2 + noise_sample * exp(-time * 12.0) * 0.3) * _attack(time, 0.003)
		CUE_MARKET_CONFIRM:
			var confirm_frequency := 520.0 if progress < 0.48 else 690.0
			return sin(TAU * confirm_frequency * time) * 0.42 * _bell_envelope(progress)
		CUE_MARKET_DROP:
			var falling_frequency := lerpf(720.0, 245.0, progress)
			var falling := sin(TAU * falling_frequency * time)
			var low_pulse := sin(TAU * 122.0 * time) * exp(-time * 7.0)
			return (falling * 0.42 + low_pulse * 0.26) * _soft_release(progress)
		CUE_PROFIT_TICK:
			var tick_frequency := 560.0 if progress < 0.45 else 820.0
			return (sin(TAU * tick_frequency * time) * 0.4 + sin(TAU * tick_frequency * 2.0 * time) * 0.1) * _bell_envelope(progress)
		CUE_PROFIT_FINAL:
			var note_index := mini(int(progress * 4.0), 3)
			var notes := [440.0, 554.37, 659.25, 880.0]
			var note: float = notes[note_index]
			var chord := sin(TAU * note * time) + sin(TAU * note * 1.5 * time) * 0.28
			return chord * 0.36 * _soft_release(progress) * _attack(time, 0.008)
		CUE_SECURITY_SHOT:
			var security_crack := noise_sample * exp(-time * 46.0)
			var security_body := sin(TAU * 74.0 * time) * exp(-time * 25.0)
			return (security_crack * 0.38 + security_body * 0.76) * _attack(time, 0.002)
		CUE_SECURITY_ALERT:
			var alert_step := int(time * 9.0) % 2
			var alert_frequency := 525.0 if alert_step == 0 else 690.0
			return (sin(TAU * alert_frequency * time) * 0.38 + sin(TAU * 112.0 * time) * 0.12) * _soft_release(progress)
		CUE_PLAYER_HIT:
			var impact_body := sin(TAU * (78.0 - progress * 22.0) * time) * exp(-time * 13.0)
			return (impact_body * 0.82 + noise_sample * exp(-time * 25.0) * 0.18) * _attack(time, 0.002)
		CUE_EXTRACTION_START:
			return (sin(TAU * 330.0 * time) * 0.27 + sin(TAU * 440.0 * time) * 0.13) * _soft_release(progress)
		CUE_RUN_SETTLED:
			var chord := sin(TAU * 220.0 * time) * 0.3 + sin(TAU * 330.0 * time) * 0.2 + sin(TAU * 440.0 * time) * 0.12
			return chord * _attack(time, 0.035) * exp(-time * 2.6)
	return 0.0

func _attack(time: float, attack_duration: float) -> float:
	return clampf(time / maxf(attack_duration, 0.0001), 0.0, 1.0)

func _soft_release(progress: float) -> float:
	return sin(PI * clampf(progress, 0.0, 1.0)) * (1.0 - progress * 0.35)

func _bell_envelope(progress: float) -> float:
	return _attack(progress, 0.06) * exp(-progress * 3.2)

func _build_player_pools() -> void:
	for _index in range(WORLD_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.max_distance = 26.0
		player.unit_size = 3.2
		add_child(player)
		_world_players.append(player)
	for _index in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_ui_players.append(player)

func _next_world_player() -> AudioStreamPlayer3D:
	for player in _world_players:
		if not player.playing:
			return player
	var player := _world_players[_world_cursor % _world_players.size()]
	_world_cursor += 1
	player.stop()
	return player

func _next_ui_player() -> AudioStreamPlayer:
	for player in _ui_players:
		if not player.playing:
			return player
	var player := _ui_players[_ui_cursor % _ui_players.size()]
	_ui_cursor += 1
	player.stop()
	return player
