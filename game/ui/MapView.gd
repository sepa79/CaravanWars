extends Control
class_name MapView

const CityPlacerModule = preload("res://map/CityPlacer.gd")

var map_data: Dictionary = {}
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var dragging: bool = false
var show_roads: bool = true
var show_rivers: bool = true
var show_cities: bool = true
var show_crossings: bool = false
@export var crossing_color: Color = Color.YELLOW
@export var crossing_size: float = 8.0
var show_regions: bool = true

func set_map_data(data: Dictionary) -> void:
    map_data = data
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
            _adjust_zoom(1.1)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
            _adjust_zoom(1.0 / 1.1)
        elif mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                dragging = true
            else:
                dragging = false
    elif event is InputEventMouseMotion and dragging:
        var mm: InputEventMouseMotion = event
        pan_offset -= mm.relative / _current_scale()
        queue_redraw()

func _adjust_zoom(factor: float) -> void:
    var old_zoom: float = zoom_level
    zoom_level = clamp(zoom_level * factor, min_zoom, max_zoom)
    var base_scale: float = _base_scale()
    var offset: Vector2 = _base_offset(base_scale)
    var center_screen: Vector2 = size * 0.5
    var center_map: Vector2 = pan_offset + (center_screen - offset) / (base_scale * old_zoom)
    pan_offset = center_map - (center_screen - offset) / (base_scale * zoom_level)
    queue_redraw()

func _base_scale() -> float:
    return min(size.x / CityPlacerModule.WIDTH, size.y / CityPlacerModule.HEIGHT)

func _current_scale() -> float:
    return _base_scale() * zoom_level

func _base_offset(base_scale: float) -> Vector2:
    return (size - Vector2(CityPlacerModule.WIDTH, CityPlacerModule.HEIGHT) * base_scale) / 2.0

func _draw() -> void:
    if map_data.is_empty():
        return
    var base_scale: float = _base_scale()
    var draw_scale: float = base_scale * zoom_level
    var offset: Vector2 = _base_offset(base_scale) - pan_offset * draw_scale
    var regions: Dictionary = map_data.get("regions", {})
    if show_regions:
        for region in regions.values():
            var pts := PackedVector2Array()
            for p in region.boundary_nodes:
                pts.append(p * draw_scale + offset)
            if pts.size() >= 3:
                var base_color := Color.from_hsv(hash(region.id) % 360 / 360.0, 0.6, 0.8)
                var fill_color: Color = base_color
                fill_color.a = 0.3
                var outline_color: Color = base_color
                outline_color.a = 0.8
                draw_polygon(pts, PackedColorArray([fill_color]))
                for i in range(pts.size()):
                    var a: Vector2 = pts[i]
                    var b: Vector2 = pts[(i + 1) % pts.size()]
                    draw_line(a, b, outline_color, 1.0)
    var roads: Dictionary = map_data.get("roads", {})
    if show_roads:
        for edge in roads.get("edges", {}).values():
            var pts: PackedVector2Array = edge.polyline
            for i in range(pts.size() - 1):
                draw_line(pts[i] * draw_scale + offset, pts[i + 1] * draw_scale + offset, Color.WHITE, 1.0)
    if show_rivers:
        for river in map_data.get("rivers", []):
            for i in range(river.size() - 1):
                draw_line(river[i] * draw_scale + offset, river[i + 1] * draw_scale + offset, Color.BLUE, 1.0)
    if show_cities:
        for city in map_data.get("cities", []):
            draw_circle(city * draw_scale + offset, 4.0, Color.RED)
    if show_crossings:
        for node in roads.get("nodes", {}).values():
            if node.type == "crossing":
                var center: Vector2 = node.pos2d * draw_scale + offset
                var s: float = crossing_size
                var diamond := PackedVector2Array([
                    center + Vector2(0, -s),
                    center + Vector2(s, 0),
                    center + Vector2(0, s),
                    center + Vector2(-s, 0),
                ])
                draw_polygon(diamond, PackedColorArray([crossing_color]))

func set_show_roads(value: bool) -> void:
    show_roads = value
    queue_redraw()

func set_show_rivers(value: bool) -> void:
    show_rivers = value
    queue_redraw()

func set_show_cities(value: bool) -> void:
    show_cities = value
    queue_redraw()

func set_show_crossings(value: bool) -> void:
    show_crossings = value
    queue_redraw()

func set_show_regions(value: bool) -> void:
    show_regions = value
    queue_redraw()
