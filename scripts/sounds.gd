extends Node

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}

func _ready() -> void:
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -19
		add_child(player)
		voices.append(player)
	for entry in [["jump", 430.0, 0.07], ["gem", 900.0, 0.12], ["oops", 150.0, 0.18], ["gate", 620.0, 0.16], ["win", 1100.0, 0.25], ["spring", 320.0, 0.13]]:
		clips[entry[0]] = tone(entry[1], entry[2])

func tone(frequency: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var phase := float(i) / 22050
		var envelope := sin(PI * i / count)
		data.encode_s16(i * 2, int(sin(TAU * frequency * phase) * envelope * 11000))
	stream.data = data
	return stream

func play_cue(cue: String) -> void:
	if not enabled or not clips.has(cue) or AudioServer.get_driver_name() == "Dummy":
		return
	for player in voices:
		if not player.playing:
			player.stream = clips[cue]
			player.play()
			return

func _exit_tree() -> void:
	for player in voices:
		player.stop()
		player.stream = null
	clips.clear()
