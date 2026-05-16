extends Node2D

@export var debug_mode: bool = false

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

@export var grid_width: int = 30
@export var grid_height: int = 30

@export var tiles_per_chunk: int = 16

@export var biomes: Array[BiomeData] = []

@export var world_seed: int = randi()
@export var noise_frequency: float = 0.05

var _noise: FastNoiseLite

func _ready() -> void:
	if not debug_mode:
		$Camera2D.queue_free()
		set_process(false)
		
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency

	generate_chunk_map()

func generate_chunk_map() -> void:
	if biomes.is_empty():
		printerr("No biomes provided. Cannot generate terrain.")
		return
	
	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x = (x * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			var center_tile_y = (y * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
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
