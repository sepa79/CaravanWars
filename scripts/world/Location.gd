extends Resource
class_name Location

@export var id: StringName
@export var displayName: String = ""
@export var description: String = ""
@export var mapPos: Vector2i = Vector2i.ZERO
@export var mapIcon: StringName
@export var neighbors: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var data: Dictionary = {}
