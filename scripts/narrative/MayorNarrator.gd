extends INarrator
class_name MayorNarrator

func render(recipient_id:int, events:Array) -> Array[Dictionary]:
	print("MayorNarrator:", events)
	return []

func _on_event(event:Dictionary) -> void:
	render(-1, [event])
