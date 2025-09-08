extends Node

signal language_changed

const LANG_EN := "en"
const LANG_PL := "pl"
var current_lang: String = LANG_EN
var strings: Dictionary = {}

func _ready() -> void:
    load_language(current_lang)

func load_language(lang: String) -> void:
    var cfg := ConfigFile.new()
    var path := "res://i18n/%s.cfg" % lang
    if cfg.load(path) != OK:
        push_error("Failed to load language: %s" % path)
        return
    strings.clear()
    for key in cfg.get_section_keys("strings"):
        strings[key] = cfg.get_value("strings", key, key)
    current_lang = lang
    language_changed.emit()

func t(key: String) -> String:
    return strings.get(key, key)

func toggle_language() -> void:
    var lang := LANG_PL if current_lang == LANG_EN else LANG_EN
    load_language(lang)
