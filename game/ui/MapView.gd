extends Control
class_name MapView

var map_data: Dictionary = {}
var map_width: float = 150.0
var map_height: float = 150.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var dragging: bool = false
var show_roads: bool = true
var show_rivers: bool = true
var show_cities: bool = true
var show_forts: bool = true
var show_crossroads: bool = true
var show_bridges: bool = true
var show_fords: bool = true
var show_fertility: bool = false
var show_roughness: bool = false
@export var crossroad_color: Color = Color.YELLOW
@export var crossroad_size: float = 8.0
@export var bridge_color: Color = Color(0.6, 0.4, 0.2)
@export var ford_color: Color = Color.CYAN
var show_regions: bool = true
var debug_logged: bool = false
var edit_mode: bool = false
var dragging_city: bool = false
var selected_city: int = -1
const RoadNetworkModule = preload("res://mapview/RoadNetwork.gd")
const MapNodeModule = preload("res://mapview/MapNode.gd")
var road_helper: MapViewRoadNetwork = RoadNetworkModule.new(RandomNumberGenerator.new())
var road_mode: String = ""
var selected_road_class: String = "road"
var selected_node: int = -1
var hovered_node: int = -1
var hovered_edge: int = -1

signal cities_changed(cities: Array)

func set_map_data(data: Dictionary) -> void:
    map_data = data
    debug_logged = false
    map_width = data.get("width", map_width)
    map_height = data.get("height", map_height)
    var regions: Dictionary = map_data.get("regions", {})
    for region in regions.values():
        print("[MapView] region %s nodes: %s" % [region.id, region.boundary_nodes])
    queue_redraw()

func set_edit_mode(value: bool) -> void:
    edit_mode = value
    dragging_city = false
    selected_city = -1

func set_road_mode(mode: String) -> void:
    road_mode = mode
    selected_node = -1
    hovered_node = -1
    hovered_edge = -1
    queue_redraw()

func set_road_class(cls: String) -> void:
    selected_road_class = cls

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
                if road_mode == "add":
                    var node_id: int = _road_node_at_point(mb.position)
                    if node_id != -1:
                        if selected_node == -1:
                            selected_node = node_id
                        else:
                            road_helper.connect_nodes(map_data.get("roads", {}), selected_node, node_id, 5.0, selected_road_class)
                            selected_node = -1
                            queue_redraw()
                elif road_mode == "delete":
                    var edge_id: int = _road_edge_at_point(mb.position)
                    if edge_id != -1:
                        road_helper.remove_edge(map_data.get("roads", {}), edge_id)
                        hovered_edge = -1
                        queue_redraw()
                elif road_mode == "fort":
                    var v_edge: int = _road_edge_at_point(mb.position)
                    if v_edge != -1:
                        road_helper.insert_node_on_edge(map_data.get("roads", {}), v_edge, MapNodeModule.TYPE_FORT)
                        hovered_edge = -1
                        queue_redraw()
                elif edit_mode:
                    var idx: int = _city_at_point(mb.position)
                    if idx != -1:
                        selected_city = idx
                        dragging_city = true
                    else:
                        dragging = true
                else:
                    dragging = true
            else:
                if dragging_city:
                    dragging_city = false
                    selected_city = -1
                    cities_changed.emit(map_data.get("cities", []))
                dragging = false
            accept_event()
    elif event is InputEventMouseMotion:
        var mm: InputEventMouseMotion = event
        if edit_mode and dragging_city and selected_city != -1:
            var map_pos: Vector2 = _screen_to_map(mm.position)
            map_pos.x = clamp(map_pos.x, 0.0, map_width)
            map_pos.y = clamp(map_pos.y, 0.0, map_height)
            map_data.get("cities", [])[selected_city] = map_pos
            queue_redraw()
            accept_event()
        elif road_mode == "add":
            hovered_node = _road_node_at_point(mm.position)
            queue_redraw()
            accept_event()
        elif road_mode == "delete" or road_mode == "fort":
            hovered_edge = _road_edge_at_point(mm.position)
            queue_redraw()
            accept_event()
        elif dragging:
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
    if show_fertility:
        var fert: Array = map_data.get("fertility", [])
        var rect_size: Vector2 = Vector2(draw_scale, draw_scale)
        for y in range(fert.size()):
            var row: Array = fert[y]
            for x in range(row.size()):
                var col: Color = Color(0, row[x], 0, 0.4)
                var pos: Vector2 = Vector2(x, y) * draw_scale + offset
                draw_rect(Rect2(pos, rect_size), col, true)
    if show_roughness:
        var rough: Array = map_data.get("roughness", [])
        var rect_size_r: Vector2 = Vector2(draw_scale, draw_scale)
        for ry in range(rough.size()):
            var rrow: Array = rough[ry]
            for rx in range(rrow.size()):
                var rcol: Color = Color(rrow[rx], 0, 0, 0.4)
                var rpos: Vector2 = Vector2(rx, ry) * draw_scale + offset
                draw_rect(Rect2(rpos, rect_size_r), rcol, true)
    var roads: Dictionary = map_data.get("roads", {})
    if show_roads:
        var edges: Dictionary = roads.get("edges", {})
        var nodes: Dictionary = roads.get("nodes", {})
        var class_colors: Dictionary = {
            "path": Color(0.6, 0.6, 0.6),
            "road": Color(0.8, 0.7, 0.5),
            "roman": Color(1.0, 0.9, 0.3),
        }
        var class_widths: Dictionary = {
            "path": 1.0,
            "road": 2.0,
            "roman": 3.0,
        }
        for edge in edges.values():
            var cls: String = String(edge.road_class).to_lower()
            var pts: PackedVector2Array = edge.polyline
            var col: Color = class_colors.get(cls, Color.WHITE)
            var w: float = class_widths.get(cls, 1.0)
            for i in range(pts.size() - 1):
                var a: Vector2 = pts[i]
                var b: Vector2 = pts[i + 1]
                draw_line(a * draw_scale + offset, b * draw_scale + offset, col, w)

        if road_mode == "add":
            if hovered_node != -1 and nodes.has(hovered_node):
                var hpos: Vector2 = nodes[hovered_node].pos2d * draw_scale + offset
                draw_circle(hpos, 6.0, Color.YELLOW)
            if selected_node != -1 and nodes.has(selected_node):
                var spos: Vector2 = nodes[selected_node].pos2d * draw_scale + offset
                draw_circle(spos, 6.0, Color.GREEN)
        elif road_mode == "delete" or road_mode == "fort":
            if hovered_edge != -1 and edges.has(hovered_edge):
                var hedge = edges[hovered_edge]
                var hpts: PackedVector2Array = hedge.polyline
                var hcolor: Color = Color.RED if road_mode == "delete" else Color.YELLOW
                for i in range(hpts.size() - 1):
                    var ha: Vector2 = hpts[i] * draw_scale + offset
                    var hb: Vector2 = hpts[i + 1] * draw_scale + offset
                    draw_line(ha, hb, hcolor, 2.0)

        var font: Font = get_theme_default_font()
        var font_size: int = get_theme_default_font_size()
        if font:
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
                    var length: float = edge.attrs.get("length", edge.polyline[0].distance_to(edge.polyline[1]))
                    var cur_edge = edge
                    var cur_node = other_id
                    while nodes[cur_node].type != "city":
                        var conn: Array = adjacency.get(cur_node, [])
                        if conn.size() < 2:
                            break
                        var next_edge = conn[0] if conn[0] != cur_edge else conn[1]
                        var next_node: int = next_edge.endpoints[0] if next_edge.endpoints[1] == cur_node else next_edge.endpoints[1]
                        path.append(nodes[next_node].pos2d)
                        length += next_edge.attrs.get("length", nodes[cur_node].pos2d.distance_to(nodes[next_node].pos2d))
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
            var pts: Array[Vector2] = []
            if river is Curve2D:
                for p in river.tessellate():
                    pts.append(p)
            else:
                pts = river
            for i in range(pts.size() - 1):
                draw_line(pts[i] * draw_scale + offset, pts[i + 1] * draw_scale + offset, Color.BLUE, 1.0)
    if show_cities:
        var capitals: Array = map_data.get("capitals", [])
        var cities: Array = map_data.get("cities", [])
        for i in range(cities.size()):
            var city: Vector2 = cities[i]
            var pos: Vector2 = city * draw_scale + offset
            if capitals.has(i):
                draw_circle(pos, 6.0, Color.YELLOW)
                draw_circle(pos, 3.0, Color.RED)
            else:
                draw_circle(pos, 4.0, Color.RED)
        for village in map_data.get("villages", []):
            var vpos: Vector2 = village * draw_scale + offset
            draw_circle(vpos, 3.0, Color(0.8, 0.6, 0.4))
    if show_forts or show_crossroads or show_bridges or show_fords:
        for node in roads.get("nodes", {}).values():
            var center: Vector2 = node.pos2d * draw_scale + offset
            if node.type == MapNodeModule.TYPE_FORT and show_forts:
                var s_f: float = 4.0
                var rect := PackedVector2Array([
                    center + Vector2(-s_f, -s_f),
                    center + Vector2(s_f, -s_f),
                    center + Vector2(s_f, s_f),
                    center + Vector2(-s_f, s_f),
                ])
                draw_polygon(rect, PackedColorArray([Color.ORANGE]))
            elif node.type == MapNodeModule.TYPE_CROSSROAD and show_crossroads:
                var s_cr: float = crossroad_size
                var diamond := PackedVector2Array([
                    center + Vector2(0, -s_cr),
                    center + Vector2(s_cr, 0),
                    center + Vector2(0, s_cr),
                    center + Vector2(-s_cr, 0),
                ])
                draw_polygon(diamond, PackedColorArray([crossroad_color]))
            elif node.type == MapNodeModule.TYPE_BRIDGE and show_bridges:
                var s_b: float = crossroad_size
                var rect := PackedVector2Array([
                    center + Vector2(-s_b, -s_b * 0.5),
                    center + Vector2(s_b, -s_b * 0.5),
                    center + Vector2(s_b, s_b * 0.5),
                    center + Vector2(-s_b, s_b * 0.5),
                ])
                draw_polygon(rect, PackedColorArray([bridge_color]))
            elif node.type == MapNodeModule.TYPE_FORD and show_fords:
                draw_circle(center, crossroad_size * 0.5, ford_color)

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

func _city_at_point(screen_pos: Vector2) -> int:
    var cities: Array = map_data.get("cities", [])
    var base_scale: float = _base_scale()
    var draw_scale: float = base_scale * zoom_level
    var offset: Vector2 = _base_offset(base_scale) - pan_offset * draw_scale
    for i in range(cities.size()):
        var c: Vector2 = cities[i] * draw_scale + offset
        if c.distance_to(screen_pos) <= 6.0:
            return i
    return -1

func _road_node_at_point(screen_pos: Vector2) -> int:
    var roads: Dictionary = map_data.get("roads", {})
    var nodes: Dictionary = roads.get("nodes", {})
    var base_scale: float = _base_scale()
    var draw_scale: float = base_scale * zoom_level
    var offset: Vector2 = _base_offset(base_scale) - pan_offset * draw_scale
    for id in nodes.keys():
        var node = nodes[id]
        var pos: Vector2 = node.pos2d * draw_scale + offset
        if pos.distance_to(screen_pos) <= 6.0:
            return id
    return -1

func _road_edge_at_point(screen_pos: Vector2) -> int:
    var roads: Dictionary = map_data.get("roads", {})
    var edges: Dictionary = roads.get("edges", {})
    var base_scale: float = _base_scale()
    var draw_scale: float = base_scale * zoom_level
    var offset: Vector2 = _base_offset(base_scale) - pan_offset * draw_scale
    for id in edges.keys():
        var edge = edges[id]
        var pts: Array = edge.polyline
        for i in range(pts.size() - 1):
            var a: Vector2 = pts[i] * draw_scale + offset
            var b: Vector2 = pts[i + 1] * draw_scale + offset
            var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(screen_pos, a, b)
            if closest_point.distance_to(screen_pos) <= 3.0:
                return id
    return -1

func _screen_to_map(screen_pos: Vector2) -> Vector2:
    var base_scale: float = _base_scale()
    var draw_scale: float = base_scale * zoom_level
    var offset: Vector2 = _base_offset(base_scale) - pan_offset * draw_scale
    return (screen_pos - offset) / draw_scale

func set_show_roads(value: bool) -> void:
    show_roads = value
    queue_redraw()

func set_show_rivers(value: bool) -> void:
    show_rivers = value
    queue_redraw()

func set_show_cities(value: bool) -> void:
    show_cities = value
    queue_redraw()

    queue_redraw()

func set_show_forts(value: bool) -> void:
    show_forts = value
    queue_redraw()

func set_show_crossroads(value: bool) -> void:
    show_crossroads = value
    queue_redraw()

func set_show_bridges(value: bool) -> void:
    show_bridges = value
    queue_redraw()

func set_show_fords(value: bool) -> void:
    show_fords = value
    queue_redraw()

func set_show_regions(value: bool) -> void:
    show_regions = value
    queue_redraw()

func set_show_fertility(value: bool) -> void:
    show_fertility = value
    queue_redraw()

func set_show_roughness(value: bool) -> void:
    show_roughness = value
    queue_redraw()
