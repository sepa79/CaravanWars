extends Control
class_name MapView

signal cities_changed(cities: Array)

const MAX_PREVIEW_DIMENSION := 512

var map_data: Dictionary = {}

var _map_dimension: int = 0
var _terrain_texture: Texture2D
var _fertility_texture: Texture2D
var _roughness_texture: Texture2D
var _river_polylines: Array[Dictionary] = []
var _road_polylines: Array[Dictionary] = []
var _kingdom_polygons: Array[Dictionary] = []
var _kingdom_borders: Array[Dictionary] = []
var _cities: Array[Dictionary] = []
var _villages: Array[Dictionary] = []
var _forts: Array[Dictionary] = []
var _bridge_points: Array[Vector2] = []
var _ford_points: Array[Vector2] = []
var _crossroad_points: Array[Vector2] = []
var _kingdom_colors: Dictionary = {}

var _edit_mode_enabled: bool = false
var _active_road_mode: String = ""
var _road_class: String = ""

var _show_roads: bool = true
var _show_rivers: bool = true
var _show_cities: bool = true
var _show_villages: bool = true
var _show_crossroads: bool = false
var _show_bridges: bool = false
var _show_fords: bool = false
var _show_regions: bool = true
var _show_forts: bool = true
var _show_fertility: bool = false
var _show_roughness: bool = false

func set_map_data(data: Dictionary) -> void:
    map_data = data
    _rebuild_preview()
    emit_signal("cities_changed", _cities)
    queue_redraw()

func set_edit_mode(value: bool) -> void:
    _edit_mode_enabled = value

func set_road_mode(mode: String) -> void:
    _active_road_mode = mode

func set_road_class(cls: String) -> void:
    _road_class = cls

func set_show_roads(value: bool) -> void:
    if _show_roads == value:
        return
    _show_roads = value
    queue_redraw()

func set_show_rivers(value: bool) -> void:
    if _show_rivers == value:
        return
    _show_rivers = value
    queue_redraw()

func set_show_cities(value: bool) -> void:
    if _show_cities == value:
        return
    _show_cities = value
    queue_redraw()

func set_show_villages(value: bool) -> void:
    if _show_villages == value:
        return
    _show_villages = value
    queue_redraw()

func set_show_crossroads(value: bool) -> void:
    if _show_crossroads == value:
        return
    _show_crossroads = value
    queue_redraw()

func set_show_bridges(value: bool) -> void:
    if _show_bridges == value:
        return
    _show_bridges = value
    queue_redraw()

func set_show_fords(value: bool) -> void:
    if _show_fords == value:
        return
    _show_fords = value
    queue_redraw()

func set_show_regions(value: bool) -> void:
    if _show_regions == value:
        return
    _show_regions = value
    queue_redraw()

func set_show_forts(value: bool) -> void:
    if _show_forts == value:
        return
    _show_forts = value
    queue_redraw()

func set_show_fertility(value: bool) -> void:
    if _show_fertility == value:
        return
    _show_fertility = value
    queue_redraw()

func set_show_roughness(value: bool) -> void:
    if _show_roughness == value:
        return
    _show_roughness = value
    queue_redraw()

func set_layer_visible(layer: String, visible: bool) -> void:
    match layer:
        "roads":
            set_show_roads(visible)
        "rivers":
            set_show_rivers(visible)
        "cities":
            set_show_cities(visible)
        "villages":
            set_show_villages(visible)
        "forts":
            set_show_forts(visible)
        "crossroads":
            set_show_crossroads(visible)
        "bridges":
            set_show_bridges(visible)
        "fords":
            set_show_fords(visible)
        "regions":
            set_show_regions(visible)
        "fertility":
            set_show_fertility(visible)
        "roughness":
            set_show_roughness(visible)
        _:
            pass

func get_kingdom_colors() -> Dictionary:
    var copy := {}
    for kingdom_id in _kingdom_colors.keys():
        copy[kingdom_id] = _kingdom_colors[kingdom_id]
    return copy

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _rebuild_preview() -> void:
    _terrain_texture = null
    _fertility_texture = null
    _roughness_texture = null
    _river_polylines = []
    _road_polylines = []
    _kingdom_polygons = []
    _kingdom_borders = []
    _cities = []
    _villages = []
    _forts = []
    _bridge_points = []
    _ford_points = []
    _crossroad_points = []
    _kingdom_colors.clear()
    _map_dimension = int(map_data.get("meta", {}).get("map_size", 0))
    if _map_dimension <= 0:
        return

    var terrain: Dictionary = map_data.get("terrain", {})
    var heightmap: PackedFloat32Array = terrain.get("heightmap", PackedFloat32Array())
    var sea_mask: PackedByteArray = terrain.get("sea_mask", PackedByteArray())
    var slope_map: PackedFloat32Array = terrain.get("slope", PackedFloat32Array())
    if heightmap.size() == _map_dimension * _map_dimension:
        _terrain_texture = _build_heightmap_texture(heightmap, sea_mask)
    if slope_map.size() == _map_dimension * _map_dimension:
        _roughness_texture = _build_overlay_texture(slope_map, Color(0.35, 0.2, 0.55, 0.55))

    var biomes: Dictionary = map_data.get("biomes", {})
    var rainfall_map: PackedFloat32Array = biomes.get("rainfall_map", PackedFloat32Array())
    if rainfall_map.size() == _map_dimension * _map_dimension:
        _fertility_texture = _build_overlay_texture(rainfall_map, Color(0.2, 0.55, 0.25, 0.5))

    var rivers: Dictionary = map_data.get("rivers", {})
    _river_polylines = rivers.get("polylines", [])

    var roads: Dictionary = map_data.get("roads", {})
    _road_polylines = roads.get("polylines", [])
    _bridge_points = _extract_bridge_points(_road_polylines)
    _ford_points = _extract_ford_points(_road_polylines)
    _crossroad_points = _find_crossroads(_road_polylines)

    var settlements: Dictionary = map_data.get("settlements", {})
    _cities = settlements.get("cities", [])
    _villages = settlements.get("villages", [])

    var forts: Dictionary = map_data.get("forts", {})
    _forts = forts.get("points", [])

    var kingdoms: Dictionary = map_data.get("kingdoms", {})
    _kingdom_polygons = kingdoms.get("polygons", [])
    _kingdom_borders = kingdoms.get("borders", [])
    _build_kingdom_colors(_kingdom_polygons)

func _build_heightmap_texture(heightmap: PackedFloat32Array, sea_mask: PackedByteArray) -> Texture2D:
    var preview_dimension := min(MAX_PREVIEW_DIMENSION, _map_dimension)
    if preview_dimension <= 0:
        return null
    var scale := float(_map_dimension) / float(preview_dimension)
    var image := Image.create(preview_dimension, preview_dimension, false, Image.FORMAT_RGBA8)
    for py in range(preview_dimension):
        var source_y := clamp(int(floor(py * scale)), 0, _map_dimension - 1)
        for px in range(preview_dimension):
            var source_x := clamp(int(floor(px * scale)), 0, _map_dimension - 1)
            var index := source_y * _map_dimension + source_x
            var height_value := heightmap[index]
            var is_water := not sea_mask.is_empty() and sea_mask[index] == 1
            image.set_pixel(px, py, _height_to_color(height_value, is_water))
    return ImageTexture.create_from_image(image)

func _build_overlay_texture(values: PackedFloat32Array, tint: Color) -> Texture2D:
    var preview_dimension := min(MAX_PREVIEW_DIMENSION, _map_dimension)
    if preview_dimension <= 0:
        return null
    var scale := float(_map_dimension) / float(preview_dimension)
    var image := Image.create(preview_dimension, preview_dimension, false, Image.FORMAT_RGBA8)
    for py in range(preview_dimension):
        var source_y := clamp(int(floor(py * scale)), 0, _map_dimension - 1)
        for px in range(preview_dimension):
            var source_x := clamp(int(floor(px * scale)), 0, _map_dimension - 1)
            var index := source_y * _map_dimension + source_x
            var strength := clamp(values[index], 0.0, 1.0)
            var overlay := Color(tint.r, tint.g, tint.b, tint.a * strength)
            image.set_pixel(px, py, overlay)
    return ImageTexture.create_from_image(image)

func _height_to_color(value: float, is_water: bool) -> Color:
    var clamped := clamp(value, 0.0, 1.0)
    if is_water:
        var shallow := Color(0.11, 0.25, 0.55)
        var deep := Color(0.04, 0.1, 0.32)
        return deep.lerp(shallow, clamp(clamped * 1.5, 0.0, 1.0))
    var low := Color(0.25, 0.35, 0.18)
    var high := Color(0.65, 0.6, 0.5)
    return low.lerp(high, pow(clamped, 0.8))

func _extract_bridge_points(roads: Array[Dictionary]) -> Array[Vector2]:
    var points: Array[Vector2] = []
    for road in roads:
        if not road.get("crosses_river", false):
            continue
        var path: PackedVector2Array = road.get("points", PackedVector2Array())
        if path.size() < 2:
            continue
        if road.get("type", "") == "primary":
            var middle_index := int(path.size() / 2)
            points.append(path[middle_index])
    return points

func _extract_ford_points(roads: Array[Dictionary]) -> Array[Vector2]:
    var points: Array[Vector2] = []
    for road in roads:
        if not road.get("crosses_river", false):
            continue
        var path: PackedVector2Array = road.get("points", PackedVector2Array())
        if path.size() < 2:
            continue
        if road.get("type", "") != "primary":
            var middle_index := int(path.size() / 2)
            points.append(path[middle_index])
    return points

func _find_crossroads(roads: Array[Dictionary]) -> Array[Vector2]:
    var counts: Dictionary = {}
    for road in roads:
        var path: PackedVector2Array = road.get("points", PackedVector2Array())
        if path.size() < 2:
            continue
        _accumulate_crossroad_point(counts, path[0])
        _accumulate_crossroad_point(counts, path[path.size() - 1])
    var result: Array[Vector2] = []
    for key in counts.keys():
        var count: int = counts[key]
        if count >= 3:
            result.append(_point_from_key(key))
    return result

func _accumulate_crossroad_point(counts: Dictionary, point: Vector2) -> void:
    var key := _point_key(point)
    counts[key] = counts.get(key, 0) + 1

func _point_key(point: Vector2) -> String:
    return "%s:%s" % [int(round(point.x)), int(round(point.y))]

func _point_from_key(key: String) -> Vector2:
    var parts := key.split(":")
    if parts.size() != 2:
        return Vector2.ZERO
    return Vector2(parts[0].to_int(), parts[1].to_int())

func _build_kingdom_colors(polygons: Array[Dictionary]) -> void:
    var seed_value := int(map_data.get("meta", {}).get("seed", 0))
    for polygon in polygons:
        var kingdom_id := polygon.get("kingdom_id", -1)
        if kingdom_id < 0 or _kingdom_colors.has(kingdom_id):
            continue
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_value + kingdom_id * 997
        var hue := fmod(rng.randf(), 1.0)
        var color := Color.from_hsv(hue, 0.6, 0.9)
        _kingdom_colors[kingdom_id] = color

func _draw() -> void:
    if _map_dimension <= 0:
        return
    var rect := Rect2(Vector2.ZERO, size)
    if _terrain_texture != null:
        draw_texture_rect(_terrain_texture, rect, false)
    if _show_fertility and _fertility_texture != null:
        draw_texture_rect(_fertility_texture, rect, false)
    if _show_roughness and _roughness_texture != null:
        draw_texture_rect(_roughness_texture, rect, false)
    var scale := _current_scale()
    if _show_regions:
        _draw_regions(scale)
    if _show_rivers:
        _draw_rivers(scale)
    if _show_roads:
        _draw_roads(scale)
    if _show_cities:
        _draw_cities(scale)
    if _show_villages:
        _draw_villages(scale)
    if _show_forts:
        _draw_forts(scale)
    if _show_crossroads:
        _draw_crossroads(scale)
    if _show_bridges:
        _draw_bridges(scale)
    if _show_fords:
        _draw_fords(scale)

func _current_scale() -> Vector2:
    if _map_dimension <= 0:
        return Vector2.ONE
    return Vector2(size.x / float(_map_dimension), size.y / float(_map_dimension))

func _to_view(point: Vector2, scale: Vector2) -> Vector2:
    return Vector2(point.x * scale.x, point.y * scale.y)

func _draw_regions(scale: Vector2) -> void:
    for polygon in _kingdom_polygons:
        var points: PackedVector2Array = polygon.get("polygon", PackedVector2Array())
        if points.size() < 3:
            continue
        var transformed := PackedVector2Array()
        for point in points:
            transformed.append(_to_view(point, scale))
        var kingdom_id := polygon.get("kingdom_id", -1)
        var base_color: Color = _kingdom_colors.get(kingdom_id, Color(0.5, 0.5, 0.5))
        draw_colored_polygon(transformed, base_color.with_alpha(0.2))
        var closed := transformed.duplicate()
        closed.append(transformed[0])
        draw_polyline(closed, base_color, 2.0)
    for border in _kingdom_borders:
        var border_points: PackedVector2Array = border.get("points", PackedVector2Array())
        if border_points.size() < 2:
            continue
        var transformed_border := PackedVector2Array()
        for point in border_points:
            transformed_border.append(_to_view(point, scale))
        draw_polyline(transformed_border, Color(0.8, 0.8, 0.8), 1.5)

func _draw_rivers(scale: Vector2) -> void:
    for river in _river_polylines:
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        var transformed := PackedVector2Array()
        for point in points:
            transformed.append(_to_view(point, scale))
        var width := river.get("width", 1.0)
        var line_width := max(1.0, width * (scale.x + scale.y) * 0.25)
        draw_polyline(transformed, Color(0.2, 0.45, 0.9), line_width)

func _draw_roads(scale: Vector2) -> void:
    for road in _road_polylines:
        var points: PackedVector2Array = road.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        var transformed := PackedVector2Array()
        for point in points:
            transformed.append(_to_view(point, scale))
        var tint := Color(0.7, 0.6, 0.45)
        if road.get("type", "") == "secondary":
            tint = Color(0.6, 0.55, 0.4)
        draw_polyline(transformed, tint, 2.0)

func _draw_cities(scale: Vector2) -> void:
    for city in _cities:
        var position: Vector2 = city.get("position", Vector2.ZERO)
        var view_position := _to_view(position, scale)
        var radius := max(4.0, min(scale.x, scale.y) * 3.0)
        draw_circle(view_position, radius, Color(0.85, 0.2, 0.2))

func _draw_villages(scale: Vector2) -> void:
    for village in _villages:
        var position: Vector2 = village.get("position", Vector2.ZERO)
        var view_position := _to_view(position, scale)
        var radius := max(2.0, min(scale.x, scale.y) * 2.0)
        draw_circle(view_position, radius, Color(0.85, 0.65, 0.35))

func _draw_forts(scale: Vector2) -> void:
    for fort in _forts:
        var position: Vector2 = fort.get("position", Vector2.ZERO)
        var view_position := _to_view(position, scale)
        var size_hint := max(4.0, min(scale.x, scale.y) * 3.0)
        var rect := Rect2(view_position - Vector2(size_hint, size_hint) * 0.5, Vector2(size_hint, size_hint))
        draw_rect(rect, Color(0.95, 0.55, 0.15))

func _draw_crossroads(scale: Vector2) -> void:
    for point in _crossroad_points:
        var view_position := _to_view(point, scale)
        var radius := max(3.0, min(scale.x, scale.y) * 2.5)
        var diamond := PackedVector2Array([
            view_position + Vector2(0, -radius),
            view_position + Vector2(radius, 0),
            view_position + Vector2(0, radius),
            view_position + Vector2(-radius, 0),
        ])
        draw_colored_polygon(diamond, Color(0.95, 0.85, 0.2, 0.9))

func _draw_bridges(scale: Vector2) -> void:
    for point in _bridge_points:
        var view_position := _to_view(point, scale)
        var size_hint := max(3.0, min(scale.x, scale.y) * 2.0)
        var rect := Rect2(view_position - Vector2(size_hint, size_hint * 0.5), Vector2(size_hint * 2.0, size_hint))
        draw_rect(rect, Color(0.65, 0.45, 0.2))

func _draw_fords(scale: Vector2) -> void:
    for point in _ford_points:
        var view_position := _to_view(point, scale)
        var radius := max(2.0, min(scale.x, scale.y) * 1.5)
        draw_circle(view_position, radius, Color(0.4, 0.85, 0.9))
