extends Node2D

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

@export var grid_width: int = 30
@export var grid_height: int = 30

@export var biomes: Array[BiomeData] = []

var _noise: FastNoiseLite

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.05

	generate_chunk_map()

func generate_chunk_map() -> void:
	if biomes.is_empty():
		printerr("No biomes provided. Cannot generate terrain.")
		return
	
	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x = (x * 16) + 8
			var center_tile_y = (y * 16) + 8
			var macro_noise: float = _noise.get_noise_2d(center_tile_x, center_tile_y)
			
			var chunk_instance: Node2D = null
			
			for biome in biomes:
				if macro_noise >= biome.min_noise and macro_noise < biome.max_noise:
					if not biome.chunk_scenes.is_empty():
						chunk_instance = biome.chunk_scenes.pick_random().instantiate() as Node2D
					break
			
			if not chunk_instance:
				print("Warning: No biome found for noise value ", macro_noise, " at chunk (", x, ", ", y, "). Using default biome.")
				chunk_instance = biomes[0].chunk_scenes.pick_random().instantiate() as Node2D
			
			chunk_instance.position = Vector2(x, y) * chunk_size_pixels
			
			if chunk_instance.has_method("generate_terrain_from_noise"):
				chunk_instance.generate_terrain_from_noise(_noise, Vector2i(x, y))
				
			add_child(chunk_instance)
