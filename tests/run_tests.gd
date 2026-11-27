extends SceneTree
## Each test_*.gd extends RefCounted and provides test_*() -> String methods.
## An empty string passes. A non-empty string explains a failure.


const TIMEOUT_S: float = 60.0
const MAX_MESSAGES: int = 5


## Counts script errors (a runtime error inside GDScript, such as a call on null) as they
## are logged. Only ERROR_TYPE_SCRIPT counts. Plain engine errors, warnings, shader errors
## and push_error() calls a test makes on purpose are other types and are ignored.
## The engine may call _log_error from any thread, so every field is read and written
## under a mutex, through the methods below only.
class ScriptErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _count: int = 0
	var _messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		_count += 1
		if _messages.size() < MAX_MESSAGES:
			_messages.append("%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function])
		_mutex.unlock()

	func count() -> int:
		_mutex.lock()
		var n: int = _count
		_mutex.unlock()
		return n

	## The first kept message at or after the given count (a snapshot), or a bare note
	## when that message was not kept.
	func message_from(snapshot: int) -> String:
		_mutex.lock()
		var text: String = _messages[snapshot] if snapshot < _messages.size() else "(message not kept)"
		_mutex.unlock()
		return text

	## The kept messages from the snapshot on, joined for printing (at most MAX_MESSAGES in all).
	func messages_from(snapshot: int) -> String:
		_mutex.lock()
		var parts: Array[String] = []
		for i: int in range(snapshot, _messages.size()):
			parts.append(_messages[i])
		_mutex.unlock()
		return "; ".join(parts)


var _errors: ScriptErrorLog = ScriptErrorLog.new()
## Script errors already pinned on a test, a suite construction or the guard probe.
var _accounted: int = 0


func _init() -> void:
	# As early as possible, so autoload _init and _ready errors are counted too.
	OS.add_logger(_errors)


func _initialize() -> void:
	# Wait for the project's autoloads to finish loading their data.
	_run_tests.call_deferred()
	# Watchdog: if a suite aborts before quit(), fail instead of hanging.
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)


func _finish(code: int) -> void:
	OS.remove_logger(_errors)
	quit(code)


func _on_timeout() -> void:
	print("FAIL runner timed out after %d s" % int(TIMEOUT_S))
	_finish(2)


func _run_tests() -> void:
	# Prompts follow the device at once here; the settle has its own tests. Loaded at run
	# time: naming Controls here would compile it (and, through it, scripts that need the
	# autoloads) before the autoloads exist, as this runner is the --script main loop.
	(load("res://scripts/ui/controls.gd") as GDScript).set(&"settle_text", false)
	var passed: int = 0
	var failed: int = 0
	failed += await _guard_probe(OS.get_environment("RUNNER_SELFTEST") == "1")
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

		var errors_before_new: int = _errors.count()
		var suite: RefCounted = script.new() as RefCounted
		var new_errors: int = _errors.count() - errors_before_new
		_accounted += new_errors
		if suite == null:
			print("FAIL %s: could not construct the suite" % file)
			failed += 1
			continue
		if new_errors > 0:
			print("FAIL %s: script error while the suite was constructed: %s" % [file, _errors.message_from(errors_before_new)])
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

	# Deferred calls and queue_free work from the last tests run on the next frames.
	await process_frame
	await process_frame
	var stray: int = _errors.count() - _accounted
	if stray > 0:
		print("FAIL %d script error(s) outside any test: %s" % [stray, _errors.messages_from(_accounted)])
		failed += 1

	if passed + failed == 0:
		print("FAIL no test scripts found")
		failed += 1
	print("Tests: %d passed, %d failed" % [passed, failed])
	_finish(1 if failed > 0 else 0)


## Runs one test method. Returns "" on a pass, else the reason it failed. A test fails if
## a script error was logged while it ran, or if it returns anything but a String. A test
## that hits a script error is aborted by Godot and a typed `-> String` method then returns
## "", which the old runner counted as a pass; the logger is what catches it.
func _run_one(suite: RefCounted, method_name: String) -> String:
	var errors_before: int = _errors.count()
	var result: Variant = await suite.call(method_name)
	var new_errors: int = _errors.count() - errors_before
	_accounted += new_errors
	if new_errors > 0:
		return "script error while this test ran: %s" % _errors.message_from(errors_before)
	if not result is String:
		return "expected a String result, got %s" % type_string(typeof(result))
	return result


## Proves the guard on every run: a method that crashes must fail and a plain pass must
## pass. The crash logs one SCRIPT ERROR block, which is expected. With RUNNER_SELFTEST=1
## the rest of the probe runs too (null return, a failure message, and an await then a
## crash or a pass). Returns the number of guard faults found (0 when it works).
func _guard_probe(full: bool) -> int:
	print("Guard probe: one SCRIPT ERROR block below is expected (crash_on_null); it is not a failure.")
	var helper: RefCounted = (load("res://tests/helpers/crashing_suite.gd") as GDScript).new() as RefCounted
	var faults: int = 0
	var expect_fail: Array[String] = ["crash_on_null"]
	var expect_pass: Array[String] = ["plain_pass"]
	if full:
		expect_fail.append_array(["return_null", "await_then_crash"])
		expect_pass.append("await_then_pass")
	for method_name: String in expect_fail:
		var reason: String = await _run_one(helper, method_name)
		print("PROBE %s -> %s" % [method_name, reason if not reason.is_empty() else "PASSED (guard broken)"])
		if reason.is_empty():
			faults += 1
	for method_name: String in expect_pass:
		var reason: String = await _run_one(helper, method_name)
		if not reason.is_empty():
			print("PROBE %s wrongly failed: %s" % [method_name, reason])
			faults += 1
	if full and await _run_one(helper, "plain_fail") != "nope":
		print("PROBE plain_fail lost its message")
		faults += 1
	if faults > 0:
		print("FAIL the runner's script-error guard is broken (%d fault(s))" % faults)
	return faults
