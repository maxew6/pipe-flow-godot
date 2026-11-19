extends Node
## Autoload "Feedback": tiny procedurally generated sound effects plus haptics.
## The sounds are synthesised in code (simple tones), so there are no audio
## files or licences to worry about. They are placeholders for real SFX later.
## Both channels obey the toggles stored in SaveManager.data.

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams["click"] = _synth([760.0], 0.05, 0.30, false)
	_streams["rotate"] = _synth([420.0, 560.0], 0.035, 0.30, false)
	_streams["start"] = _synth([392.0, 523.0, 659.0], 0.09, 0.30, false)
	_streams["error"] = _synth([196.0, 147.0], 0.14, 0.28, true)
	_streams["success"] = _synth([523.0, 659.0, 784.0, 1046.0], 0.12, 0.32, false)


func play(sound: String) -> void:
	if not SaveManager.data.sfx_on:
		return
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


func vibrate(milliseconds: int = 15) -> void:
	if not SaveManager.data.vibration_on:
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(milliseconds)


func vibration_supported() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


## Builds a short mono 16-bit tone sequence with a decaying envelope.
func _synth(freqs: Array, note_seconds: float, volume: float, square: bool) -> AudioStreamWAV:
	var per_note := int(float(RATE) * note_seconds)
	var total := per_note * freqs.size()
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for n in freqs.size():
		var freq: float = freqs[n]
		for i in per_note:
			var t := float(i) / float(RATE)
			var envelope := pow(1.0 - float(i) / float(per_note), 1.5)
			var wave := sin(TAU * freq * t)
			if square:
				wave = 1.0 if wave >= 0.0 else -1.0
			var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
			bytes.encode_s16((n * per_note + i) * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
