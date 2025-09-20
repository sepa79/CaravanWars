extends SceneTree

const TestSuites := [
    preload("res://tests/mapgen/HexMapGeneratorTerrainTest.gd"),
    preload("res://tests/mapgen/Phase1TerrainPipelineTest.gd"),
]

func _initialize() -> void:
    var total_failures: int = 0
    for suite_script in TestSuites:
        var suite: RefCounted = suite_script.new()
        var failure_count: int = suite.run()
        if failure_count > 0:
            total_failures += failure_count
            for message in suite.get_failures():
                push_error("[tests] %s" % message)
    if total_failures > 0:
        quit(1)
        return
    print("[tests] Map generation suites passed")
    quit()
