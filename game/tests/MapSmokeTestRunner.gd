extends Node

const LOG_PREFIX := "[MapSmokeTest]"
const START_MENU_SCENE_PATH := "res://scenes/StartMenu.tscn"
const MAP_SETUP_SCENE_PATH := "res://ui/MapSetupScreen.tscn"
const START_MENU_SINGLE_PLAYER_BUTTON_PATH := "MainMenu/SinglePlayer"
const MAP_SETUP_START_BUTTON_PATH := "HBox/ControlsScroll/Controls/Buttons/Start"
const MAP_SETUP_BACK_BUTTON_PATH := "HBox/ControlsScroll/Controls/Buttons/Back"
const MAP_SETUP_MAP_VIEW_PATH := "HBox/MapRow/MapView"
const MAP_SETUP_MAP_SIZE_SPIN_PATH := "HBox/ControlsScroll/Controls/Params/Width"
const PHASE_WAIT_START_MENU := 0
const PHASE_PRESS_SINGLE_PLAYER := 1
const PHASE_WAIT_MAP_SETUP := 2
const PHASE_WAIT_MAP_GENERATION := 3
const PHASE_DONE := 4
const PHASE_TIMEOUT_SECONDS := 20.0

var _phase: int = PHASE_WAIT_START_MENU
var _phase_elapsed: float = 0.0
var _start_menu: Control
var _map_view: Node
var _finished: bool = false
var _map_setup: Control

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
        PHASE_WAIT_MAP_GENERATION:
            _maybe_verify_map_generated(current_scene)
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
    var map_view_node: Node = map_setup.get_node_or_null(MAP_SETUP_MAP_VIEW_PATH)
    if start_button == null or back_button == null or map_view_node == null:
        _fail("Map setup missing expected controls.")
        return
    var run_mode := _get_net_run_mode()
    if run_mode != "single":
        _fail("Net.run_mode expected 'single' but was '%s'." % run_mode)
        return
    _map_setup = map_setup
    _map_view = map_view_node
    print("%s Map setup loaded (start=%s back=%s map_view=%s)." % [LOG_PREFIX, start_button.name, back_button.name, map_view_node.name])
    _configure_for_smoke_test(map_setup)
    _advance_phase()

func _configure_for_smoke_test(map_setup: Control) -> void:
    var map_size_spin: SpinBox = map_setup.get_node_or_null(MAP_SETUP_MAP_SIZE_SPIN_PATH) as SpinBox
    if map_size_spin == null:
        return
    var desired_size := 256.0
    if map_size_spin.value > desired_size:
        map_size_spin.value = desired_size

func _maybe_verify_map_generated(_current_scene: Node) -> void:
    if _map_view == null:
        _fail("Map view missing before verifying map generation.")
        return
    var map_data_variant: Variant = _map_view.get("map_data")
    if not (map_data_variant is Dictionary):
        _fail("Map view map_data property missing or invalid.")
        return
    var map_data: Dictionary = map_data_variant
    if map_data.is_empty():
        return
    var meta: Dictionary = map_data.get("meta", {})
    if meta.is_empty():
        _fail("Map generator returned map data without metadata.")
        return
    var map_size := int(meta.get("map_size", 0))
    if map_size <= 0:
        _fail("Map generator returned invalid map size %d." % map_size)
        return
    var kingdom_count := int(meta.get("kingdom_count", 0))
    if kingdom_count <= 0:
        _fail("Map generator returned invalid kingdom count %d." % kingdom_count)
        return
    var terrain: Dictionary = map_data.get("terrain", {})
    var heightmap: PackedFloat32Array = terrain.get("heightmap", PackedFloat32Array())
    if heightmap.size() != map_size * map_size:
        _fail("Map generator heightmap expected %d elements but found %d." % [map_size * map_size, heightmap.size()])
        return
    var validation_variant: Variant = map_data.get("validation", [])
    if not (validation_variant is Array):
        _fail("Map generator validation payload missing or invalid.")
        return
    var validation_issues: Array = validation_variant
    print("%s Map generated (size=%d kingdoms=%d validation_issues=%d)." % [LOG_PREFIX, map_size, kingdom_count, validation_issues.size()])
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
