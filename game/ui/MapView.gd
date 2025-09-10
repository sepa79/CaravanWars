extends Control
class_name MapView

var map_data: Dictionary = {}
var map_width: float = 100.0
var map_height: float = 100.0
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
var debug_logged: bool = false

func set_map_data(data: Dictionary) -> void:
    map_data = data
    debug_logged = false
    map_width = data.get("width", map_width)
    map_height = data.get("height", map_height)
    var regions: Dictionary = map_data.get("regions", {})
    for region in regions.values():
        print("[MapView] region %s nodes: %s" % [region.id, region.boundary_nodes])
    queue_redraw()

func get_kingdom_colors() -> Dictionary:
    var colors: Dictionary = {}
    var regions: Dictionary = map_data.get("regions", {})
    for region in regions.values():
        if not colors.has(region.kingdom_id):
            colors[region.kingdom_id] = Color.from_hsv(hash(region.kingdom_id) % 360 / 360.0, 0.6, 0.8)
    return colors

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
            _adjust_zoom(1.1)
            accept_event()
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
            _adjust_zoom(1.0 / 1.1)
            accept_event()
        elif mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                dragging = true
            else:
                dragging = false
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        var mm: InputEventMouseMotion = event
        pan_offset -= mm.relative / _current_scale()
        queue_redraw()
        accept_event()

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
    return min(size.x / map_width, size.y / map_height)

func _current_scale() -> float:
    return _base_scale() * zoom_level

func _base_offset(base_scale: float) -> Vector2:
    return (size - Vector2(map_width, map_height) * base_scale) / 2.0

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
            if not debug_logged:
                print("[MapView] region %s screen pts: %s" % [region.id, pts])
            if pts.size() >= 3:
                var base_color := Color.from_hsv(hash(region.kingdom_id) % 360 / 360.0, 0.6, 0.8)
                var fill_color: Color = base_color
                fill_color.a = 0.3
                var outline_color: Color = base_color
                outline_color.a = 0.8
                draw_polygon(pts, PackedColorArray([fill_color]))
                for i in range(pts.size()):
                    var a: Vector2 = pts[i]
                    var b: Vector2 = pts[(i + 1) % pts.size()]
                    draw_line(a, b, outline_color, 1.0)
        if not debug_logged:
            print("[MapView] drew %s regions" % regions.size())
            debug_logged = true
    var roads: Dictionary = map_data.get("roads", {})
    if show_roads:
        var edges: Dictionary = roads.get("edges", {})
        for edge in edges.values():
            var pts: PackedVector2Array = edge.polyline
            for i in range(pts.size() - 1):
                var a: Vector2 = pts[i]
                var b: Vector2 = pts[i + 1]
                draw_line(a * draw_scale + offset, b * draw_scale + offset, Color.WHITE, 1.0)

        var font: Font = get_theme_default_font()
        var font_size: int = get_theme_default_font_size()
        if font:
            var nodes: Dictionary = roads.get("nodes", {})
            var adjacency: Dictionary = {}
            for edge in edges.values():
                var ep0: int = edge.endpoints[0]
                var ep1: int = edge.endpoints[1]
                if not adjacency.has(ep0):
                    adjacency[ep0] = []
                if not adjacency.has(ep1):
                    adjacency[ep1] = []
                adjacency[ep0].append(edge)
                adjacency[ep1].append(edge)
            var handled: Dictionary = {}
            for node_id in nodes.keys():
                var node = nodes[node_id]
                if node.type != "city":
                    continue
                for edge in adjacency.get(node_id, []):
                    var other_id: int = edge.endpoints[0] if edge.endpoints[1] == node_id else edge.endpoints[1]
                    var path: Array[Vector2] = edge.polyline.duplicate()
                    var length: float = edge.polyline[0].distance_to(edge.polyline[1])
                    var cur_edge = edge
                    var cur_node = other_id
                    while nodes[cur_node].type != "city":
                        var conn: Array = adjacency.get(cur_node, [])
                        if conn.size() < 2:
                            break
                        var next_edge = conn[0] if conn[0] != cur_edge else conn[1]
                        var next_node: int = next_edge.endpoints[0] if next_edge.endpoints[1] == cur_node else next_edge.endpoints[1]
                        path.append(nodes[next_node].pos2d)
                        length += nodes[cur_node].pos2d.distance_to(nodes[next_node].pos2d)
                        cur_edge = next_edge
                        cur_node = next_node
                    var other_city_id: int = cur_node
                    var key: String = "%d_%d" % [min(node_id, other_city_id), max(node_id, other_city_id)]
                    if handled.has(key) or node_id == other_city_id:
                        continue
                    handled[key] = true
                    var mid: Vector2 = _polyline_midpoint(path, length)
                    var pos: Vector2 = mid * draw_scale + offset + Vector2(0, -4)
                    draw_string(font, pos, "%d" % int(round(length)), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
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

func _polyline_midpoint(points: Array, total_length: float) -> Vector2:
    var half: float = total_length / 2.0
    var acc: float = 0.0
    for i in range(points.size() - 1):
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var seg: float = a.distance_to(b)
        if acc + seg >= half:
            var t: float = (half - acc) / seg
            return a.lerp(b, t)
        acc += seg
    return points[0]

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
