extends Node2D

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

@export var grid_width: int = 10
@export var grid_height: int = 10

@export var chunk_sea_scenes: Array[PackedScene] = []
@export var chunk_island_scenes: Array[PackedScene] = []
@export var chunk_rock_scenes: Array[PackedScene] = []

var _noise: FastNoiseLite

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.05

	generate_chunk_map()

func generate_chunk_map() -> void:
	if chunk_sea_scenes.is_empty():
		printerr("No sea chunk scenes provided. Cannot generate terrain.")
		return
	if chunk_island_scenes.is_empty():
		printerr("No island chunk scenes provided. ")
	if chunk_rock_scenes.is_empty():
		printerr("No rock chunk scenes provided. ")
		
	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x = (x * 16) + 8
			var center_tile_y = (y * 16) + 8
			var macro_noise: float = _noise.get_noise_2d(center_tile_x, center_tile_y)
			
			var chunk_instance: Node2D
			
			if macro_noise < 0.0:
				chunk_instance = chunk_sea_scenes.pick_random().instantiate() as Node2D
			else:
				if macro_noise < 0.3 and not chunk_island_scenes.is_empty():
					chunk_instance = chunk_island_scenes.pick_random().instantiate() as Node2D
				elif not chunk_rock_scenes.is_empty():
					chunk_instance = chunk_rock_scenes.pick_random().instantiate() as Node2D
				else:
					chunk_instance = chunk_sea_scenes.pick_random().instantiate() as Node2D
			
			chunk_instance.position = Vector2(x, y) * chunk_size_pixels
			
			if chunk_instance.has_method("generate_terrain_from_noise"):
				chunk_instance.generate_terrain_from_noise(_noise, Vector2i(x, y))
				
			add_child(chunk_instance)
