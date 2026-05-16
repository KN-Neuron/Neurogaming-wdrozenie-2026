extends Node2D

@export var debug_mode: bool = false

@export var start_pos_tiles: Vector2 = Vector2(10, 10)
@export var end_pos_tiles: Vector2 = Vector2(150, 200)
@export var path_width_tiles: float = 15.0

@export var chunk_size_pixels: Vector2 = Vector2(512, 512)

@export var grid_width: int = 50
@export var grid_height: int = 50

@export var tiles_per_chunk: int = 16

@export var biomes: Array[BiomeData] = []

@export var use_random_seed: bool = true
@export var world_seed: int = 0

@export var noise_frequency: float = 0.05

var _noise: FastNoiseLite

func _ready() -> void:
	if not debug_mode:
		$Camera2D.queue_free()

	if use_random_seed:
		randomize()
		world_seed = randi()
	
	print("Generated world seed: ", world_seed)

	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency

	generate_chunk_map()

	if debug_mode:
		_create_debug_marker(start_pos_tiles, "Start", Color.GREEN)
		_create_debug_marker(end_pos_tiles, "End", Color.RED)

		var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
		$Camera2D.position = start_pos_tiles * tile_size

func generate_chunk_map() -> void:
	if biomes.is_empty():
		printerr("No biomes provided. Cannot generate terrain.")
		return
	
	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x = (x * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			var center_tile_y = (y * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			var macro_noise: float = _get_world_noise(center_tile_x, center_tile_y)
			
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
				chunk_instance.generate_terrain_from_noise(_get_world_noise, Vector2i(x, y))
				
			add_child(chunk_instance)

func _get_world_noise(global_x: int, global_y: int) -> float:
	var base_noise: float = _noise.get_noise_2d(global_x, global_y)

	var current_point = Vector2(global_x, global_y)
	var closest_path_point = Geometry2D.get_closest_point_to_segment(current_point, start_pos_tiles, end_pos_tiles)
	var distance_to_path = current_point.distance_to(closest_path_point)

	if distance_to_path < path_width_tiles:
		var mask_strength = distance_to_path / path_width_tiles
		var carved_noise = lerp(-1.0, base_noise, mask_strength)

		return min(carved_noise, base_noise)

	return base_noise

func _create_debug_marker(tile_pos: Vector2, marker_text: String, marker_color: Color) -> void:
	var marker = Node2D.new()
	marker.z_index = 100

	var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
	marker.position = tile_pos * tile_size

	var rect = ColorRect.new()
	rect.color = marker_color
	rect.size = Vector2(tile_size / 2.0, tile_size / 2.0)
	rect.position = -rect.size / 2.0

	var label = Label.new()
	label.text = marker_text
	label.add_theme_font_size_override("font_size", 128)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-label.size.x / 2.0, -250.0)
	marker.add_child(label)

	add_child(marker)
