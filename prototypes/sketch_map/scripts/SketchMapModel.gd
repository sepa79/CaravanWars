class_name SketchMapModel
extends RefCounted

const GRAPH_PATH: String = "res://data/demo_graph.json"

var nodes_by_id: Dictionary = {}
var edges: Array[Dictionary] = []
var rivers: Array[Dictionary] = []
var map_nodes: Dictionary = {}
var map_edges: Dictionary = {}
var map_rivers: Dictionary = {}
var bought_map_nodes: Dictionary = {}
var bought_map_edges: Dictionary = {}
var bought_map_rivers: Dictionary = {}
var bought_map_quality: float = -1.0
var copied_map_count: int = 0
var notes: Array[Dictionary] = []
var current_node_id: String = "wroclaw_gate_inn"


func load_demo_graph() -> void:
    var file: FileAccess = FileAccess.open(GRAPH_PATH, FileAccess.READ)
    if file == null:
        push_error("Could not open sketch map graph: %s" % GRAPH_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Sketch map graph is not a dictionary.")
        return

    nodes_by_id.clear()
    edges.clear()
    rivers.clear()
    map_nodes.clear()
    map_edges.clear()
    map_rivers.clear()
    bought_map_nodes.clear()
    bought_map_edges.clear()
    bought_map_rivers.clear()
    bought_map_quality = -1.0
    copied_map_count = 0
    notes.clear()

    for node_value: Variant in parsed.get("nodes", []):
        if typeof(node_value) == TYPE_DICTIONARY:
            var node: Dictionary = node_value
            nodes_by_id[str(node.get("id", ""))] = node

    for edge_value: Variant in parsed.get("edges", []):
        if typeof(edge_value) == TYPE_DICTIONARY:
            edges.append(edge_value)

    for river_value: Variant in parsed.get("rivers", []):
        if typeof(river_value) == TYPE_DICTIONARY:
            rivers.append(river_value)

    discover_node("wroclaw_gate_inn", "visited")
    discover_nearby("wroclaw_gate_inn", "seen")


func travel_to(node_id: String) -> bool:
    if not nodes_by_id.has(node_id):
        return false
    if not _has_known_or_true_edge(current_node_id, node_id):
        return false

    discover_edge_between(current_node_id, node_id, "visited")
    current_node_id = node_id
    discover_node(node_id, "visited")
    discover_nearby(node_id, "seen")
    reveal_rivers_near(node_id)
    notes.append({
        "text": "Road note: travelled to %s." % str(nodes_by_id[node_id].get("name", node_id)),
        "node_id": node_id,
        "source": "visited"
    })
    return true


func reveal_from_hill() -> void:
    if current_node_id != "low_hill":
        notes.append({
            "text": "Need a high place to draw beyond the road.",
            "node_id": current_node_id,
            "source": "system"
        })
        return

    discover_node("opole_road_camp", "seen")
    discover_node("opole_market", "heard")
    notes.append({
        "text": "From the hill: smoke and roofs lie somewhere toward Opole.",
        "node_id": "low_hill",
        "source": "seen"
    })


func add_tavern_rumor() -> void:
    discover_node("opole_market", "heard")
    discover_edge_between("opole_road_camp", "opole_market", "heard")
    notes.append({
        "text": "Tavern rumor: the Opole road runs on, but folk argue about distance.",
        "node_id": "opole_market",
        "source": "heard"
    })


func buy_regional_map() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    bought_map_quality = snappedf(rng.randf_range(0.28, 0.88), 0.01)
    bought_map_nodes.clear()
    bought_map_edges.clear()
    bought_map_rivers.clear()

    var include_chance: float = lerpf(0.48, 0.98, bought_map_quality)
    for node_id: String in nodes_by_id.keys():
        if node_id == current_node_id or rng.randf() <= include_chance:
            _add_bought_node(node_id)

    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if not bought_map_nodes.has(from_id) or not bought_map_nodes.has(to_id):
            continue

        var edge_chance: float = lerpf(0.55, 1.0, bought_map_quality)
        if rng.randf() > edge_chance:
            continue

        var edge_id: String = str(edge.get("id", "%s_%s" % [from_id, to_id]))
        bought_map_edges[edge_id] = {
            "id": edge_id,
            "from": from_id,
            "to": to_id,
            "kind": str(edge.get("kind", "road")),
            "source": "bought",
            "path": _bought_edge_path(from_id, to_id, edge_id)
        }

    for river: Dictionary in rivers:
        var river_id: String = str(river.get("id", "river"))
        var points: Array[Vector2] = []
        for point_value: Variant in river.get("points", []):
            points.append(_bought_river_map_point(_array_to_vec2(point_value), river, river_id))
        if points.size() >= 2:
            bought_map_rivers[river_id] = {
                "id": river_id,
                "points": points,
                "source": "bought"
            }

    notes.append({
        "text": "Bought regional map. Seller quality estimate: %d%%." % int(round(bought_map_quality * 100.0)),
        "node_id": current_node_id,
        "source": "bought"
    })


func copy_bought_map_to_player() -> void:
    if bought_map_quality < 0.0:
        notes.append({
            "text": "No bought map to copy from.",
            "node_id": current_node_id,
            "source": "system"
        })
        return

    copied_map_count += 1
    var copied_nodes: int = 0
    var copied_edges: int = 0
    var copied_rivers: int = 0

    for node_id: String in bought_map_nodes.keys():
        if _should_skip_copy_node(node_id):
            continue

        var bought_node: Dictionary = bought_map_nodes[node_id]
        var copied_pos: Vector2 = bought_node.get("map_pos", Vector2.ZERO) + _copy_offset(node_id)
        map_nodes[node_id] = {
            "id": node_id,
            "name": str(bought_node.get("name", node_id)),
            "kind": str(bought_node.get("kind", "unknown")),
            "true_pos": bought_node.get("true_pos", copied_pos),
            "map_pos": copied_pos,
            "source": "copied",
            "accuracy": _copied_accuracy(),
            "label": "%s*" % str(bought_node.get("label", node_id)),
            "variant": abs(hash("%s:copied:%d" % [node_id, copied_map_count])) % 4
        }
        copied_nodes += 1

    for edge_id: String in bought_map_edges.keys():
        if map_edges.has(edge_id) and _source_rank(str(map_edges[edge_id].get("source", ""))) >= _source_rank("seen"):
            continue

        var bought_edge: Dictionary = bought_map_edges[edge_id]
        var from_id: String = str(bought_edge.get("from", ""))
        var to_id: String = str(bought_edge.get("to", ""))
        if not map_nodes.has(from_id) or not map_nodes.has(to_id):
            continue

        map_edges[edge_id] = {
            "id": edge_id,
            "from": from_id,
            "to": to_id,
            "kind": str(bought_edge.get("kind", "road")),
            "source": "copied",
            "accuracy": _copied_accuracy(),
            "path": _copied_edge_path(from_id, to_id, edge_id)
        }
        copied_edges += 1

    for river_id: String in bought_map_rivers.keys():
        if map_rivers.has(river_id):
            continue

        var bought_river: Dictionary = bought_map_rivers[river_id]
        var points: Array[Vector2] = []
        for point: Vector2 in bought_river.get("points", []):
            points.append(point + _copy_offset("%s:river" % river_id) * 0.35)

        if points.size() >= 2:
            map_rivers[river_id] = {
                "id": river_id,
                "points": points,
                "source": "copied"
            }
            copied_rivers += 1

    notes.append({
        "text": "Copied from bought map: %d places, %d roads, %d river fragments. Copy accuracy: %d%%." % [copied_nodes, copied_edges, copied_rivers, int(round(_copied_accuracy() * 100.0))],
        "node_id": current_node_id,
        "source": "copied"
    })


func discover_nearby(node_id: String, source: String) -> void:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if from_id == node_id:
            discover_node(to_id, source)
            discover_edge_between(from_id, to_id, source)
        elif to_id == node_id:
            discover_node(from_id, source)
            discover_edge_between(from_id, to_id, source)


func discover_node(node_id: String, source: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    if map_nodes.has(node_id):
        var existing: Dictionary = map_nodes[node_id]
        if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
            existing["source"] = source
            existing["accuracy"] = _accuracy_for_source(source)
            existing["label"] = _label_for_node(nodes_by_id[node_id], source)
            map_nodes[node_id] = existing
        return

    var node: Dictionary = nodes_by_id[node_id]
    var true_pos: Vector2 = _array_to_vec2(node.get("position", [0, 0]))
    map_nodes[node_id] = {
        "id": node_id,
        "name": str(node.get("name", node_id)),
        "kind": str(node.get("kind", "unknown")),
        "true_pos": true_pos,
        "map_pos": true_pos + _stable_offset(node_id, source),
        "source": source,
        "accuracy": _accuracy_for_source(source),
        "label": _label_for_node(node, source),
        "variant": abs(hash("%s:%s" % [node_id, source])) % 4
    }


func discover_edge_between(a_id: String, b_id: String, source: String) -> void:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if (from_id == a_id and to_id == b_id) or (from_id == b_id and to_id == a_id):
            var edge_id: String = str(edge.get("id", "%s_%s" % [a_id, b_id]))
            if map_edges.has(edge_id):
                var existing: Dictionary = map_edges[edge_id]
                if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
                    existing["source"] = source
                    existing["accuracy"] = _accuracy_for_source(source)
                    existing["path"] = _edge_path(from_id, to_id, edge_id, source)
                    map_edges[edge_id] = existing
                return

            discover_node(from_id, source)
            discover_node(to_id, source)
            map_edges[edge_id] = {
                "id": edge_id,
                "from": from_id,
                "to": to_id,
                "kind": str(edge.get("kind", "road")),
                "source": source,
                "accuracy": _accuracy_for_source(source),
                "path": _edge_path(from_id, to_id, edge_id, source)
            }
            return


func reveal_rivers_near(node_id: String) -> void:
    for river: Dictionary in rivers:
        var visible_near: Array = river.get("visible_near", [])
        if visible_near.has(node_id):
            var river_id: String = str(river.get("id", "river"))
            if not map_rivers.has(river_id):
                var points: Array[Vector2] = []
                for point_value: Variant in river.get("points", []):
                    points.append(_river_map_point(_array_to_vec2(point_value), river, river_id))
                map_rivers[river_id] = {
                    "id": river_id,
                    "points": points,
                    "source": "seen"
                }


func get_known_destinations() -> Array[String]:
    var destinations: Array[String] = []
    for edge_id: String in map_edges.keys():
        var edge: Dictionary = map_edges[edge_id]
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if from_id == current_node_id and map_nodes.has(to_id):
            destinations.append(to_id)
        elif to_id == current_node_id and map_nodes.has(from_id):
            destinations.append(from_id)
    destinations.sort()
    return destinations


func _has_known_or_true_edge(a_id: String, b_id: String) -> bool:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if (from_id == a_id and to_id == b_id) or (from_id == b_id and to_id == a_id):
            return true
    return false


func _edge_path(from_id: String, to_id: String, edge_id: String, source: String) -> PackedVector2Array:
    var from_pos: Vector2 = map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = map_nodes[to_id]["map_pos"]
    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend: float = float((abs(hash(edge_id)) % 80) - 40)
    if source == "heard":
        bend *= 1.8
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _add_bought_node(node_id: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    var node: Dictionary = nodes_by_id[node_id]
    var true_pos: Vector2 = _array_to_vec2(node.get("position", [0, 0]))
    bought_map_nodes[node_id] = {
        "id": node_id,
        "name": str(node.get("name", node_id)),
        "kind": str(node.get("kind", "unknown")),
        "true_pos": true_pos,
        "map_pos": true_pos + _bought_offset(node_id),
        "source": "bought",
        "accuracy": bought_map_quality,
        "label": _bought_label_for_node(node),
        "variant": abs(hash("%s:bought:%d" % [node_id, int(bought_map_quality * 100.0)])) % 4
    }


func _bought_edge_path(from_id: String, to_id: String, edge_id: String) -> PackedVector2Array:
    var from_pos: Vector2 = bought_map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = bought_map_nodes[to_id]["map_pos"]
    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend_strength: float = lerpf(95.0, 18.0, bought_map_quality)
    var bend: float = float((abs(hash("%s:bought" % edge_id)) % int(bend_strength * 2.0)) - int(bend_strength))
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _copied_edge_path(from_id: String, to_id: String, edge_id: String) -> PackedVector2Array:
    var from_pos: Vector2 = map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = map_nodes[to_id]["map_pos"]
    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend_strength: float = lerpf(120.0, 26.0, _copied_accuracy())
    var bend: float = float((abs(hash("%s:copied:%d" % [edge_id, copied_map_count])) % int(bend_strength * 2.0)) - int(bend_strength))
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _bought_river_map_point(true_point: Vector2, river: Dictionary, river_id: String) -> Vector2:
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not nodes_by_id.has(visible_node_id) or not bought_map_nodes.has(visible_node_id):
            continue

        var node_true_pos: Vector2 = _array_to_vec2(nodes_by_id[visible_node_id].get("position", [0, 0]))
        if true_point.distance_to(node_true_pos) <= 2.0:
            return bought_map_nodes[visible_node_id].get("map_pos", node_true_pos)

    return true_point + _bought_offset("%s:river" % river_id) * 0.45


func _river_map_point(true_point: Vector2, river: Dictionary, river_id: String) -> Vector2:
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not nodes_by_id.has(visible_node_id) or not map_nodes.has(visible_node_id):
            continue

        var node_true_pos: Vector2 = _array_to_vec2(nodes_by_id[visible_node_id].get("position", [0, 0]))
        if true_point.distance_to(node_true_pos) <= 2.0:
            return map_nodes[visible_node_id].get("map_pos", node_true_pos)

    return true_point + _stable_offset(river_id, "river") * 0.35


func _bought_offset(id: String) -> Vector2:
    var seed: int = abs(hash("%s:bought:%d" % [id, int(bought_map_quality * 100.0)]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = lerpf(92.0, 10.0, bought_map_quality)
    var variance: float = float((seed / 19) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.45 + variance))


func _copy_offset(id: String) -> Vector2:
    var seed: int = abs(hash("%s:copy:%d" % [id, copied_map_count]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = lerpf(52.0, 8.0, _copied_accuracy())
    var variance: float = float((seed / 23) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.35 + variance))


func _copied_accuracy() -> float:
    var character_copy_skill: float = 0.56
    return clamp(bought_map_quality * 0.72 + character_copy_skill * 0.28, 0.18, 0.9)


func _should_skip_copy_node(node_id: String) -> bool:
    if not map_nodes.has(node_id):
        return false

    var existing: Dictionary = map_nodes[node_id]
    return _source_rank(str(existing.get("source", ""))) >= _source_rank("seen")


func _bought_label_for_node(node: Dictionary) -> String:
    var name: String = str(node.get("name", "unknown"))
    if bought_map_quality < 0.45:
        return "%s?" % name
    return name


func _stable_offset(id: String, source: String) -> Vector2:
    var seed: int = abs(hash("%s:%s:sketch" % [id, source]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = 8.0
    match source:
        "visited":
            radius = 12.0
        "seen":
            radius = 34.0
        "heard":
            radius = 74.0
        _:
            radius = 28.0
    var variance: float = float((seed / 17) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.55 + variance))


func _accuracy_for_source(source: String) -> float:
    match source:
        "visited":
            return 0.82
        "seen":
            return 0.52
        "heard":
            return 0.24
        _:
            return 0.4


func _source_rank(source: String) -> float:
    match source:
        "visited":
            return 3.0
        "seen":
            return 2.0
        "copied":
            return 1.4
        "heard":
            return 1.0
        _:
            return 0.0


func _label_for_node(node: Dictionary, source: String) -> String:
    var name: String = str(node.get("name", "unknown"))
    if source == "heard":
        return "%s?" % name
    return name


func _array_to_vec2(value: Variant) -> Vector2:
    if typeof(value) == TYPE_ARRAY and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO
