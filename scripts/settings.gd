extends RefCounted

const Controls = preload("res://scripts/controls.gd")

var path := "user://settings.cfg"
var volume := 0.75
var reduced_motion := false
var fullscreen := false
var bindings: Dictionary = {}

func read() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var raw_volume: Variant = file.get_value("audio", "volume", 0.75)
	if (raw_volume is float or raw_volume is int) and is_finite(float(raw_volume)):
		volume = clampf(float(raw_volume),0,1)
	var raw_motion: Variant = file.get_value("display", "reduced_motion", false)
	if raw_motion is bool:
		reduced_motion = raw_motion
	var raw_bindings: Variant = file.get_value("input", "bindings", {})
	if raw_bindings is Dictionary and Controls.valid_bindings(raw_bindings):
		bindings = raw_bindings
	var raw_fullscreen: Variant = file.get_value("display", "fullscreen", false)
	if raw_fullscreen is bool:
		fullscreen = raw_fullscreen

func write() -> bool:
	var file := ConfigFile.new()
	file.set_value("input","bindings",bindings)
	file.set_value("audio","volume",volume)
	file.set_value("display","reduced_motion",reduced_motion)
	file.set_value("display","fullscreen",fullscreen)
	if file.save(path+".tmp") != OK:
		return false
	return DirAccess.rename_absolute(path+".tmp",path) == OK
