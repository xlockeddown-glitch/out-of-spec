extends SceneTree
## Each test_*.gd extends RefCounted and provides test_*() -> String methods.
## An empty string passes. A non-empty string explains a failure.


const TIMEOUT_S: float = 60.0


func _initialize() -> void:
	# Wait for the project's autoloads to finish loading their data.
	_run_tests.call_deferred()
	# Watchdog: if a suite aborts before quit(), fail instead of hanging.
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)


func _on_timeout() -> void:
	print("FAIL runner timed out after %d s" % int(TIMEOUT_S))
	quit(2)


func _run_tests() -> void:
	# Prompts follow the device at once here; the settle has its own tests.
	Controls.settle_text = false
	var passed: int = 0
	var failed: int = 0
	for file: String in DirAccess.get_files_at("res://tests"):
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue

		var script: GDScript = load("res://tests/" + file) as GDScript
		if script == null or not script.can_instantiate() or script.get_instance_base_type() != &"RefCounted":
			print("FAIL %s: expected a loadable RefCounted script" % file)
			failed += 1
			continue

		var methods: Array[String] = []
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = str(method["name"])
			if method_name.begins_with("test_"):
				methods.append(method_name)
		methods.sort()
		if methods.is_empty():
			print("FAIL %s: no test methods found" % file)
			failed += 1
			continue

		var suite: RefCounted = script.new() as RefCounted
		if suite == null:
			print("FAIL %s: could not construct the suite" % file)
			failed += 1
			continue
		for method_name: String in methods:
			var label: String = "%s::%s" % [file, method_name]
			# A test that must wait for a physics frame may await; the rest return at once.
			var result: Variant = await suite.call(method_name)
			if result is String and result.is_empty():
				print("PASS %s" % label)
				passed += 1
			else:
				var reason: String = str(result) if result is String else "expected a String result"
				print("FAIL %s: %s" % [label, reason])
				failed += 1

	if passed + failed == 0:
		print("FAIL no test scripts found")
		failed += 1
	print("Tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
