extends Node

signal state_changed(state: String)

const STATE_MENU := "MENU"
const STATE_CONNECTING_STARTING_HOST := "CONNECTING.starting_host"
const STATE_CONNECTING_JOINING_HOST := "CONNECTING.joining_host"
const STATE_CONNECTING_RETRYING := "CONNECTING.retrying"
const STATE_READY := "READY"
const STATE_GAME := "GAME"
const STATE_FAILED := "FAILED"

var state: String = STATE_MENU
var last_action: Callable = func() -> void: pass
var fail_reason: String = ""

func _set_state(new_state: String) -> void:
    state = new_state
    state_changed.emit(state)

func start_singleplayer() -> void:
    last_action = start_singleplayer
    _set_state(STATE_CONNECTING_STARTING_HOST)
    # TODO: implement single-player host and join logic
    _set_state(STATE_READY)

func start_host() -> void:
    last_action = start_host
    _set_state(STATE_CONNECTING_STARTING_HOST)
    # TODO: implement hosting logic
    _set_state(STATE_READY)

func start_join(address: String) -> void:
    last_action = func() -> void: start_join(address)
    _set_state(STATE_CONNECTING_JOINING_HOST)
    # TODO: implement joining logic
    _set_state(STATE_READY)

func retry() -> void:
    if last_action == null:
        return
    _set_state(STATE_CONNECTING_RETRYING)
    last_action.call()

func fail(reason: String) -> void:
    fail_reason = reason
    _set_state(STATE_FAILED)

func reset() -> void:
    _set_state(STATE_MENU)
