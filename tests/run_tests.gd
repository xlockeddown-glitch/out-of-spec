extends SceneTree
## Each test_*.gd extends RefCounted and provides test_*() -> String methods.
## An empty string passes. A non-empty string explains a failure.


const TIMEOUT_S: float = 60.0

## Counts script errors (a runtime error inside GDScript, such as a call on null) as they
## are logged. Only ERROR_TYPE_SCRIPT counts. Plain engine errors, warnings, shader errors
## and push_error() calls a test makes on purpose are other types and are ignored.
class ScriptErrorLog extends Logger:
	var count: int = 0
	var first_message: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		count += 1
		if first_message.is_empty():
			first_message = "%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function]


var _errors: ScriptErrorLog = ScriptErrorLog.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	# Wait for the project's autoloads to finish loading their data.
	_run_tests.call_deferred()
	# Watchdog: if a suite aborts before quit(), fail instead of hanging.
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)


func _on_timeout() -> void:
	print("FAIL runner timed out after %d s" % int(TIMEOUT_S))
	quit(2)


func _run_tests() -> void:
	# Prompts follow the device at once here; the settle has its own tests. Loaded at run
	# time: naming Controls here would compile it (and, through it, scripts that need the
	# autoloads) before the autoloads exist, as this runner is the --script main loop.
	(load("res://scripts/ui/controls.gd") as GDScript).set(&"settle_text", false)
	var passed: int = 0
	var failed: int = 0
	if OS.get_environment("RUNNER_SELFTEST") == "1":
		failed += await _selftest()
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
			var reason: String = await _run_one(suite, method_name)
			if reason.is_empty():
				print("PASS %s" % label)
				passed += 1
			else:
				print("FAIL %s: %s" % [label, reason])
				failed += 1

	if passed + failed == 0:
		print("FAIL no test scripts found")
		failed += 1
	print("Tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Runs one test method. Returns "" on a pass, else the reason it failed. A test fails if
## it returns anything but a String, or if a script error was logged while it ran (Godot
## aborts the method and the call then returns null, which used to look like a pass).
func _run_one(suite: RefCounted, method_name: String) -> String:
	var errors_before: int = _errors.count
	_errors.first_message = ""
	var result: Variant = await suite.call(method_name)
	if _errors.count > errors_before:
		return "script error: %s" % _errors.first_message
	if not result is String:
		return "expected a String result, got %s" % type_string(typeof(result))
	return result


## With RUNNER_SELFTEST=1 the runner first proves its own guard: a method that crashes
## must fail and one that returns null must fail, while a plain pass and a plain failure
## message keep their meaning. Returns the number of guard faults found (0 when it works).
func _selftest() -> int:
	var helper: RefCounted = (load("res://tests/helpers/crashing_suite.gd") as GDScript).new() as RefCounted
	var faults: int = 0
	var expect_fail: Array[String] = ["crash_on_null", "return_null"]
	for method_name: String in expect_fail:
		var reason: String = await _run_one(helper, method_name)
		print("SELFTEST %s -> %s" % [method_name, reason if not reason.is_empty() else "PASSED (guard broken)"])
		if reason.is_empty():
			faults += 1
	var ok_reason: String = await _run_one(helper, "plain_pass")
	if not ok_reason.is_empty():
		print("SELFTEST plain_pass wrongly failed: %s" % ok_reason)
		faults += 1
	if await _run_one(helper, "plain_fail") != "nope":
		print("SELFTEST plain_fail lost its message")
		faults += 1
	return faults
