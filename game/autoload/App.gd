extends Node

const MAPGEN_TEST_FLAG := "--mapgen-smoke-test"
const MAPGEN_TEST_ENV := "MAPGEN_SMOKE_TEST"
func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_args()
    var run_test: bool = args.has(MAPGEN_TEST_FLAG)
    if not run_test:
        run_test = OS.has_environment(MAPGEN_TEST_ENV)
    if run_test:
        _run_map_generator_smoke_test()

func goto_scene(path: String) -> void:
    get_tree().change_scene_to_file(path)

func _run_map_generator_smoke_test() -> void:
    ResourceLoader.load("res://mapgen/CityPlacer.gd")
    var generator_script: GDScript = ResourceLoader.load("res://mapgen/MapGenerator.gd")
    var generator: RefCounted = generator_script.new()
    var data: Dictionary = generator.generate()
    var cities: Array = data.get("cities", [])
    var villages: Array = data.get("villages", [])
    print("[MapGeneratorSmokeTest] cities=%d villages=%d" % [cities.size(), villages.size()])
    get_tree().quit()
