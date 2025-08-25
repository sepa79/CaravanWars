extends INarrator
class_name GlobalNarrator

func render(recipient_id:int, events:Array) -> Array[Dictionary]:
	print("GlobalNarrator:", events)
	return []

func _on_event(event:Dictionary) -> void:
	render(-1, [event])
