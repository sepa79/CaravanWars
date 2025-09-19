extends SceneTree

const RiversSuite := preload("res://tests/mapgen/HexMapGeneratorRiversTest.gd")

func _initialize() -> void:
    var suite := RiversSuite.new()
    var failure_count := suite.run()
    if failure_count > 0:
        for message in suite.get_failures():
            push_error("[tests] %s" % message)
        quit(1)
        return
    print("[tests] HexMapGenerator rivers suite passed")
    quit()
