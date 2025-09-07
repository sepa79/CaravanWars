extends Node

signal published(topic: String, payload: Dictionary)

const Logger = preload("res://scripts/Logger.gd")

# prościutka książka subskrypcji: topic -> [Callable, ...]
var _subs: Dictionary = {}

# rejestr "endpointów" serwera (nazwy -> Callable)
var _endpoints: Dictionary = {}

func _init() -> void:
    print("Module LoopbackServer loaded")

func _ready() -> void:
    Logger.log("Loopback", "ready")

# --- Pub/Sub ---

func subscribe(topic: String, cb: Callable) -> void:
    var arr: Array = _subs.get(topic, [])
    arr.append(cb)
    _subs[topic] = arr

func unsubscribe(topic: String, cb: Callable) -> void:
    if not _subs.has(topic):
        return
    var arr: Array = _subs[topic]
    arr.erase(cb)
    if arr.is_empty():
        _subs.erase(topic)
    else:
        _subs[topic] = arr

func publish(topic: String, payload: Dictionary = {}) -> void:
    emit_signal("published", topic, payload)
    var arr: Array = _subs.get(topic, [])
    for cb in arr:
        # każdy sub dostaje (payload) jako jedyny argument
        cb.call(payload)

# --- Endpoints (RPC-like, ale w procesie) ---

func register_endpoint(name: String, cb: Callable) -> void:
    _endpoints[name] = cb

func unregister_endpoint(name: String) -> void:
    _endpoints.erase(name)

## wywołanie "serwera"
func call_endpoint(name: String, args: Dictionary = {}) -> Dictionary:
    var cb: Callable = _endpoints.get(name, Callable())
    if not cb.is_valid():
        push_warning("[Loopback] endpoint not found: %s" % name)
        return {"ok": false, "error": "endpoint_not_found", "name": name}
    var result = cb.call(args)
    # wynik normalizujemy do Dictionary
    if typeof(result) != TYPE_DICTIONARY:
        return {"ok": true, "data": result}
    return result
