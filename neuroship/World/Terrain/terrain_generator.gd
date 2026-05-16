extends Node2D

@export_group("Debug")
@export var debug_mode: bool = false

@export_group("Structures")
@export var start_port_scene: PackedScene
@export var end_port_scene: PackedScene

@export_group("Path")
@export var start_pos_tiles: Vector2 = Vector2(10, 10)
@export var end_pos_tiles: Vector2 = Vector2(300, 300)
@export var path_width_tiles: float = 15.0
@export var max_path_deviation: float = 80.0 

var _baked_river_path: PackedVector2Array
var _river_bounds: Rect2
var _segment_bounds: Array[Rect2]

@export_group("Chunk Generation")
@export var chunk_size_pixels: Vector2 = Vector2(512, 512)
@export var grid_width: int = 50
@export var grid_height: int = 50
@export var tiles_per_chunk: int = 16

@export_group("Biomes")
@export var biomes: Array[BiomeData]

@export_group("World Generation")
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

	_generate_river_curve()
	
	biomes.sort_custom(func(a, b): return a.upper_threshold < b.upper_threshold)

	generate_chunk_map()

	_spawn_structures()

	if debug_mode:
		# _create_debug_marker(start_pos_tiles, "Start", Color.GREEN)
		# _create_debug_marker(end_pos_tiles, "End", Color.RED)

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
				if macro_noise <= biome.upper_threshold:
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

func _get_world_noise(global_x: float, global_y: float) -> float:
	var current_point = Vector2(global_x, global_y)
	
	if not _river_bounds.has_point(current_point):
		return _noise.get_noise_2d(global_x, global_y)
	

	var total_path_vector = end_pos_tiles - start_pos_tiles
	var main_path_dir = total_path_vector.normalized()
	
	var vector_from_start = current_point - start_pos_tiles
	var is_behind_start = vector_from_start.dot(main_path_dir) < 0.0
	
	var vector_from_end = current_point - end_pos_tiles
	var is_past_end = vector_from_end.dot(main_path_dir) > 0.0
	
	var land_cap_radius = path_width_tiles * 1.5
	
	var base_noise = _noise.get_noise_2d(global_x, global_y)

	if is_behind_start and vector_from_start.length() < land_cap_radius:
		var dist = vector_from_start.length()
		var factor = 1.0 - (dist / land_cap_radius)
		return lerp(base_noise, 0.5, factor)
		
	if is_past_end and vector_from_end.length() < land_cap_radius:
		var dist = vector_from_end.length()
		var factor = 1.0 - (dist / land_cap_radius)
		return lerp(base_noise, 0.5, factor)
		
	if is_behind_start or is_past_end:
		return _noise.get_noise_2d(global_x, global_y)
		
	var min_distance_sq = 999999.0
	var path_width_sq = path_width_tiles * path_width_tiles
	var is_near_any_segment = false
	
	for i in range(_segment_bounds.size()):
		if _segment_bounds[i].has_point(current_point):
			is_near_any_segment = true
			var p1 = _baked_river_path[i]
			var p2 = _baked_river_path[i+1]
			var closest_pt = Geometry2D.get_closest_point_to_segment(current_point, p1, p2)
			
			var dist_sq = current_point.distance_squared_to(closest_pt)
			if dist_sq < min_distance_sq:
				min_distance_sq = dist_sq
	
	if is_near_any_segment and min_distance_sq < path_width_sq:
		var actual_distance = sqrt(min_distance_sq)
		var mask_strength = actual_distance / path_width_tiles 
		var carved_noise = lerp(-1.0, base_noise, mask_strength) 
		return min(base_noise, carved_noise)
		
	return base_noise

func _generate_river_curve() -> void:
	var curve = Curve2D.new()
	
	var path_vector = end_pos_tiles - start_pos_tiles
	var path_length = path_vector.length()
	var path_dir = path_vector.normalized()
	var path_normal = Vector2(-path_dir.y, path_dir.x)
	
	var handle_len = path_length * 0.25 
	
	var offset_one = randf_range(max_path_deviation * 0.5, max_path_deviation)
	if randi() % 2 == 0: 
		offset_one = -offset_one
	
	var offset_two = randf_range(max_path_deviation * 0.5, max_path_deviation)
	if offset_one > 0: 
		offset_two = -offset_two
	
	curve.add_point(start_pos_tiles)
	var point_one = start_pos_tiles + (path_vector * 0.33)
	curve.add_point(point_one + (path_normal * offset_one), -path_dir * handle_len, path_dir * handle_len)
	
	var point_two = start_pos_tiles + (path_vector * 0.66)
	curve.add_point(point_two + (path_normal * offset_two), -path_dir * handle_len, path_dir * handle_len)
	
	curve.add_point(end_pos_tiles)
	
	curve.bake_interval = 20.0 
	_baked_river_path = curve.get_baked_points()
	
	_river_bounds = Rect2(start_pos_tiles, Vector2.ZERO)
	_segment_bounds.clear()
	
	for i in range(_baked_river_path.size()):
		var p = _baked_river_path[i]
		_river_bounds = _river_bounds.expand(p)
		
		if i < _baked_river_path.size() - 1:
			var p_next = _baked_river_path[i+1]
			var seg_rect = Rect2(p, Vector2.ZERO).expand(p_next)
			_segment_bounds.append(seg_rect.grow(path_width_tiles + 2.0))
			
	_river_bounds = _river_bounds.grow(path_width_tiles + 2.0)

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

func _spawn_structures() -> void:
	var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
	
	if start_port_scene:
		var start_port = start_port_scene.instantiate() as Node2D
		start_port.position = start_pos_tiles * tile_size
		add_child(start_port)
		
	if end_port_scene:
		var end_port = end_port_scene.instantiate() as Node2D
		end_port.position = end_pos_tiles * tile_size
		add_child(end_port)
