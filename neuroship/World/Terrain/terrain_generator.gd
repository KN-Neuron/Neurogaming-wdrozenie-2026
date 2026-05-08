extends Node2D

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

# number of chunks in x and y direction
@export var grid_width: int = 5
@export var grid_height: int = 5

@export var chunk_scenes: Array[PackedScene] = []

func _ready() -> void:
	generate_chunk_map()

func generate_chunk_map() -> void:
	if chunk_scenes.is_empty():
		printerr("No chunk scenes provided. Cannot generate terrain.")
		return
		
	for x in range(grid_width):
		for y in range(grid_height):
			
			var random_chunk_scene: PackedScene = chunk_scenes.pick_random()
			
			var chunk_instance: Node2D = random_chunk_scene.instantiate()
			
			chunk_instance.position = Vector2(x, y) * chunk_size_pixels
			
			add_child(chunk_instance)
