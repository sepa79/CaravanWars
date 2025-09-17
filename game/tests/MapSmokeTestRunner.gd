extends Node

const LOG_PREFIX := "[MapSmokeTest]"
const START_MENU_SCENE_PATH := "res://scenes/StartMenu.tscn"
const MAP_SETUP_SCENE_PATH := "res://ui/MapSetupScreen.tscn"
const START_MENU_SINGLE_PLAYER_BUTTON_PATH := "MainMenu/SinglePlayer"
const MAP_SETUP_START_BUTTON_PATH := "HBox/ControlsScroll/Controls/Buttons/Start"
const MAP_SETUP_BACK_BUTTON_PATH := "HBox/ControlsScroll/Controls/Buttons/Back"
const MAP_SETUP_MAP_VIEW_PATH := "HBox/MapRow/MapView"
const PHASE_WAIT_START_MENU := 0
const PHASE_PRESS_SINGLE_PLAYER := 1
const PHASE_WAIT_MAP_SETUP := 2
const PHASE_DONE := 3
const PHASE_TIMEOUT_SECONDS := 10.0

var _phase: int = PHASE_WAIT_START_MENU
var _phase_elapsed: float = 0.0
var _start_menu: Control
var _finished: bool = false

func _ready() -> void:
    print("%s Runner armed." % LOG_PREFIX)
    set_process(true)

func _process(delta: float) -> void:
    if _finished:
        return
    _phase_elapsed += delta
    if _phase_elapsed > PHASE_TIMEOUT_SECONDS:
        _fail("Timeout waiting for phase %d" % _phase)
        return
    var current_scene := get_tree().current_scene
    match _phase:
        PHASE_WAIT_START_MENU:
            _maybe_capture_start_menu(current_scene)
        PHASE_PRESS_SINGLE_PLAYER:
            _maybe_press_single_player(current_scene)
        PHASE_WAIT_MAP_SETUP:
            _maybe_verify_map_setup(current_scene)
        PHASE_DONE:
            _finish(true)

func _maybe_capture_start_menu(current_scene: Node) -> void:
    if current_scene == null:
        return
    if current_scene.get_scene_file_path() != START_MENU_SCENE_PATH:
        return
    var start_menu: Control = current_scene as Control
    if start_menu == null or not start_menu.is_node_ready():
        return
    _start_menu = start_menu
    print("%s Start menu ready." % LOG_PREFIX)
    _advance_phase()

func _maybe_press_single_player(current_scene: Node) -> void:
    if _start_menu == null:
        _fail("Start menu missing before pressing single player.")
        return
    var single_player_button: Button = _start_menu.get_node_or_null(START_MENU_SINGLE_PLAYER_BUTTON_PATH) as Button
    if single_player_button == null:
        _fail("Could not find button at %s" % START_MENU_SINGLE_PLAYER_BUTTON_PATH)
        return
    print("%s Pressing single player." % LOG_PREFIX)
    single_player_button.button_pressed = true
    single_player_button.emit_signal("pressed")
    _advance_phase()

func _maybe_verify_map_setup(current_scene: Node) -> void:
    if current_scene == null:
        return
    if current_scene.get_scene_file_path() != MAP_SETUP_SCENE_PATH:
        return
    var map_setup: Control = current_scene as Control
    if map_setup == null or not map_setup.is_node_ready():
        return
    var start_button: Button = map_setup.get_node_or_null(MAP_SETUP_START_BUTTON_PATH) as Button
    var back_button: Button = map_setup.get_node_or_null(MAP_SETUP_BACK_BUTTON_PATH) as Button
    var map_view: Node = map_setup.get_node_or_null(MAP_SETUP_MAP_VIEW_PATH)
    if start_button == null or back_button == null or map_view == null:
        _fail("Map setup missing expected controls.")
        return
    var run_mode := _get_net_run_mode()
    if run_mode != "single":
        _fail("Net.run_mode expected 'single' but was '%s'." % run_mode)
        return
    print("%s Map setup loaded (start=%s back=%s map_view=%s)." % [LOG_PREFIX, start_button.name, back_button.name, map_view.name])
    _advance_phase()

func _advance_phase() -> void:
    _phase += 1
    if _phase > PHASE_DONE:
        _phase = PHASE_DONE
    _phase_elapsed = 0.0

func _finish(success: bool) -> void:
    if _finished:
        return
    _finished = true
    set_process(false)
    if success:
        print("%s Smoke test complete. Exiting." % LOG_PREFIX)
        get_tree().quit()
    else:
        get_tree().quit(1)

func _fail(message: String) -> void:
    push_error("%s %s" % [LOG_PREFIX, message])
    _finish(false)

func _get_net_run_mode() -> String:
    var net_node: Node = get_tree().root.get_node_or_null("Net")
    if net_node == null:
        return ""
    var run_mode_value: Variant = net_node.get("run_mode")
    if run_mode_value is String:
        return run_mode_value
    if run_mode_value == null:
        return ""
    return String(run_mode_value)
