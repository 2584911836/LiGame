extends RefCounted

const VERSION := 1
var path := "user://progress.cfg"
var last_error := OK

func read() -> Dictionary:
	var config := ConfigFile.new()
	last_error = config.load(path)
	if last_error != OK or config.get_value("run", "version", 0) != VERSION:
		return {}
	for key in ["stage", "seed", "solo"]:
		if not config.has_section_key("run", key):
			return {}
	var stage: Variant = config.get_value("run", "stage")
	var seed_id: Variant = config.get_value("run", "seed")
	var solo: Variant = config.get_value("run", "solo")
	if not stage is int or not seed_id is int or not solo is bool:
		return {}
	if stage < 1 or stage > 1000000 or seed_id < 0 or seed_id >= 1000000:
		return {}
	return {"stage": stage, "seed": seed_id, "solo": solo}

func write(stage: int, seed_id: int, solo: bool) -> bool:
	var config := ConfigFile.new()
	config.set_value("run", "version", VERSION)
	config.set_value("run", "stage", stage)
	config.set_value("run", "seed", seed_id)
	config.set_value("run", "solo", solo)
	last_error = config.save(path + ".tmp")
	if last_error != OK:
		return false
	last_error = DirAccess.rename_absolute(path + ".tmp", path)
	return last_error == OK
