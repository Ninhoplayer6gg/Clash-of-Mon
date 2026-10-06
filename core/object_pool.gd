class_name ObjectPool
extends RefCounted
## Minimal pool for RefCounted objects that implement reset().

var _free: Array = []
var _factory: Callable
var created := 0
var in_use := 0


func _init(factory: Callable, prewarm: int = 0) -> void:
	_factory = factory
	for i in prewarm:
		_free.append(_factory.call())
		created += 1


func acquire() -> Object:
	in_use += 1
	if _free.is_empty():
		created += 1
		return _factory.call()
	return _free.pop_back()


func release(obj: Object) -> void:
	in_use -= 1
	obj.reset()
	_free.append(obj)


func free_count() -> int:
	return _free.size()
