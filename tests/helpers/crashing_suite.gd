extends RefCounted
## Used only by the runner's self-test (RUNNER_SELFTEST=1). Not a test suite: it lives
## outside tests/ top level, so the runner never picks it up on its own.


func crash_on_null() -> String:
	var node: Node = null
	node.queue_free()
	return ""


func return_null() -> Variant:
	return null


func plain_pass() -> String:
	return ""


func plain_fail() -> String:
	return "nope"
