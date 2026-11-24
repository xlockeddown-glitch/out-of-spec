extends RefCounted
## Every crop's model set has all five models, so none shows the fallback box.


func test_every_crop_has_its_models() -> String:
	var roots_seen: bool = false
	for crop: Dictionary in DataManager.get_records(&"crops"):
		var model_set: String = str(crop.get("model", FarmGrid.DEFAULT_CROP_MODEL_SET))
		roots_seen = roots_seen or model_set == "tuber_stage"
		for stage: Variant in [0, 1, 2, 3, "wilted"]:
			var path: String = FarmGrid.CROP_MODEL % [model_set, stage]
			if not ResourceLoader.exists(path):
				return "%s has no %s." % [crop["id"], path]
	return "" if roots_seen else "Dust Turnip should use the tuber models."
