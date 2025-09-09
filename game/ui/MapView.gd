extends Control
class_name MapView

const CityPlacerModule = preload("res://map/CityPlacer.gd")

var map_data: Dictionary = {}

func set_map_data(data: Dictionary) -> void:
    map_data = data
    queue_redraw()

func _draw() -> void:
    if map_data.is_empty():
        return
    var map_scale: float = min(size.x / CityPlacerModule.WIDTH, size.y / CityPlacerModule.HEIGHT)
    var roads: Dictionary = map_data.get("roads", {})
    for edge in roads.get("edges", {}).values():
        var pts: PackedVector2Array = edge.polyline
        for i in range(pts.size() - 1):
            draw_line(pts[i] * map_scale, pts[i + 1] * map_scale, Color.WHITE, 1.0)
    for river in map_data.get("rivers", []):
        for i in range(river.size() - 1):
            draw_line(river[i] * map_scale, river[i + 1] * map_scale, Color.BLUE, 1.0)
    for city in map_data.get("cities", []):
        draw_circle(city * map_scale, 2.0, Color.RED)
