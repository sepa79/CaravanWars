extends Node

const CI_AUTO_QUIT_DEFAULT_DELAY_SECONDS := 0.1

var _ci_auto_quit_enabled: bool = OS.has_environment("CI_AUTO_QUIT")
var _ci_auto_quit_delay_seconds: float = CI_AUTO_QUIT_DEFAULT_DELAY_SECONDS
var _ci_quit_scheduled: bool = false

func _ready() -> void:
    if _ci_auto_quit_enabled:
        _configure_ci_auto_quit()

func goto_scene(path: String) -> void:
    get_tree().change_scene_to_file(path)

func _configure_ci_auto_quit() -> void:
    _ci_auto_quit_delay_seconds = _resolve_ci_auto_quit_delay()
    _schedule_ci_auto_quit()

func _resolve_ci_auto_quit_delay() -> float:
    if OS.has_environment("CI_AUTO_QUIT_DELAY"):
        var raw_delay: String = OS.get_environment("CI_AUTO_QUIT_DELAY").strip_edges()
        if raw_delay.is_valid_float():
            var parsed_delay: float = raw_delay.to_float()
            if parsed_delay < 0.0:
                return 0.0
            return parsed_delay
        if not raw_delay.is_empty():
            print("[App] Ignoring invalid CI_AUTO_QUIT_DELAY value '%s'." % raw_delay)
    return CI_AUTO_QUIT_DEFAULT_DELAY_SECONDS

func _schedule_ci_auto_quit() -> void:
    if _ci_quit_scheduled:
        return
    _ci_quit_scheduled = true
    if _ci_auto_quit_delay_seconds <= 0.0:
        call_deferred("_quit_for_ci")
        return
    var timer: SceneTreeTimer = get_tree().create_timer(_ci_auto_quit_delay_seconds)
    timer.timeout.connect(_quit_for_ci)

func _quit_for_ci() -> void:
    if not _ci_auto_quit_enabled:
        return
    print("[App] CI auto quit after %.2f seconds." % _ci_auto_quit_delay_seconds)
    get_tree().quit()

