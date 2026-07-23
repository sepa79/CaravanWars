extends Node

signal state_changed(state: String)

const STATE_MENU := "MENU"
const STATE_CONNECTING_STARTING_HOST := "CONNECTING.starting_host"
const STATE_CONNECTING_JOINING_HOST := "CONNECTING.joining_host"
const STATE_CONNECTING_RETRYING := "CONNECTING.retrying"
const STATE_READY := "READY"
const STATE_GAME := "GAME"
const STATE_FAILED := "FAILED"
const HANDSHAKE_TIMEOUT := 5.0

var state: String = STATE_MENU
var last_action: Callable = func() -> void: pass
var fail_reason: String = ""
var run_mode: String = ""
var _handshake_timer: Timer

func _log(msg: String) -> void:
    print("[Net] %s" % msg)

func _ready() -> void:
    _handshake_timer = Timer.new()
    _handshake_timer.one_shot = true
    add_child(_handshake_timer)
    _handshake_timer.timeout.connect(func():
        fail("errors.timeout")
    )

func _set_state(new_state: String) -> void:
    _log("state -> %s" % new_state)
    state = new_state
    state_changed.emit(state)

func start_singleplayer() -> void:
    _log("start_singleplayer")
    run_mode = "single"
    last_action = start_singleplayer
    _set_state(STATE_CONNECTING_STARTING_HOST)
    _handshake_timer.start(HANDSHAKE_TIMEOUT)
    get_tree().create_timer(0.5).timeout.connect(func():
        _handshake_timer.stop()
        _set_state(STATE_READY)
    )

func start_host() -> void:
    _log("start_host")
    run_mode = "host"
    last_action = start_host
    _set_state(STATE_CONNECTING_STARTING_HOST)
    _handshake_timer.start(HANDSHAKE_TIMEOUT)
    get_tree().create_timer(0.5).timeout.connect(func():
        _handshake_timer.stop()
        _set_state(STATE_READY)
    )

func start_join(address: String) -> void:
    _log("start_join %s" % address)
    run_mode = "join"
    last_action = func() -> void: start_join(address)
    _set_state(STATE_CONNECTING_JOINING_HOST)
    _handshake_timer.start(HANDSHAKE_TIMEOUT)
    get_tree().create_timer(0.5).timeout.connect(func():
        _handshake_timer.stop()
        _set_state(STATE_READY)
    )

func retry() -> void:
    if last_action == null:
        return
    _log("retry")
    _set_state(STATE_CONNECTING_RETRYING)
    last_action.call()

func fail(reason: String) -> void:
    _log("fail: %s" % reason)
    fail_reason = reason
    _handshake_timer.stop()
    _set_state(STATE_FAILED)

func reset() -> void:
    _log("reset")
    _handshake_timer.stop()
    _set_state(STATE_MENU)
