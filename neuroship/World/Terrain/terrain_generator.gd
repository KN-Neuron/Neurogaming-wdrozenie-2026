extends Node2D

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

# number of chunks in x and y direction
@export var grid_width: int = 10
@export var grid_height: int = 10

@export var chunk_sea_scenes: Array[PackedScene] = []
@export var chunk_island_scenes: Array[PackedScene] = []

@export var _noise: FastNoiseLite

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.1

	generate_chunk_map()

func generate_chunk_map() -> void:
	if chunk_sea_scenes.is_empty():
		printerr("No sea chunk scenes provided. Cannot generate terrain.")
		return
		
	for x in range(grid_width):
		for y in range(grid_height):
			var noise_value: float = _noise.get_noise_2d(x, y) # [-1, 1]
			var chunk_instance: Node2D
			
			if noise_value < 0.3:
				chunk_instance = chunk_sea_scenes[randi() % chunk_sea_scenes.size()].instantiate() as Node2D
			else:
				chunk_instance = chunk_island_scenes[randi() % chunk_island_scenes.size()].instantiate() as Node2D			
			
			chunk_instance.position = Vector2(x, y) * chunk_size_pixels
			add_child(chunk_instance)
