extends Node2D

@export_group("Debug")
@export var debug_mode: bool = false

@export_group("Structures")
@export var start_port_scene: PackedScene
@export var end_port_scene: PackedScene
@export var port_ground_noise_target: float = 0.4
@export var port_land_cap_multiplier: float = 1.5
@export var additional_structures: Array[PlacedStructure] = []

@export_group("Path")
@export var randomize_path: bool = true
@export var min_path_length_tiles: float = 150.0
@export var path_margin_tiles: float = 30.0
@export var path_length_multiplier_for_deviation: float = 0.25
@export var curve_bake_interval: float = 20.0
var number_of_attempts_for_random_path: int = 100

@export var start_pos_tiles: Vector2 = Vector2(10, 10)
@export var end_pos_tiles: Vector2 = Vector2(300, 300)
@export var path_width_tiles: float = 15.0
@export var max_path_deviation: float = 80.0

var _baked_river_path: PackedVector2Array
var _river_bounds: Rect2
var _segment_bounds: Array[Rect2]
var _all_structures: Array[PlacedStructure] = []

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

	if randomize_path:
		_randomize_ports()

	_initialize_structures()
	_generate_river_curve()
	
	biomes.sort_custom(func(a, b): return a.upper_threshold < b.upper_threshold)

	generate_chunk_map()
	_spawn_structures()

	if debug_mode:
		var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
		$Camera2D.position = start_pos_tiles * tile_size

func _initialize_structures() -> void:
	_all_structures.clear()
	
	var total_path_vector = end_pos_tiles - start_pos_tiles
	var main_path_dir = total_path_vector.normalized()
	var land_cap_radius = path_width_tiles * port_land_cap_multiplier
	
	if start_port_scene:
		var start_struct = PlacedStructure.new()
		start_struct.structure_name = "Start Port"
		start_struct.scene = start_port_scene
		start_struct.tile_position = start_pos_tiles
		start_struct.land_radius_tiles = land_cap_radius
		start_struct.influence_type = PlacedStructure.InfluenceType.DIRECTIONAL
		start_struct.land_direction = -main_path_dir
		_all_structures.append(start_struct)
		
	if end_port_scene:
		var end_struct = PlacedStructure.new()
		end_struct.structure_name = "End Port"
		end_struct.scene = end_port_scene
		end_struct.tile_position = end_pos_tiles
		end_struct.land_radius_tiles = land_cap_radius
		end_struct.influence_type = PlacedStructure.InfluenceType.DIRECTIONAL
		end_struct.land_direction = main_path_dir
		_all_structures.append(end_struct)
		
	for struct in additional_structures:
		if struct:
			_all_structures.append(struct)

func generate_chunk_map() -> void:
	if biomes.is_empty():
		printerr("No biomes provided. Cannot generate terrain.")
		return
	
	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x = (x * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			var center_tile_y = (y * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			
			var chunk_center_tiles = Vector2(center_tile_x, center_tile_y)
			var macro_noise: float = _get_world_noise(center_tile_x, center_tile_y)
			
			for struct in _all_structures:
				if struct.influence_type != PlacedStructure.InfluenceType.NONE:
					var dist = chunk_center_tiles.distance_to(struct.tile_position)
					if dist < (struct.land_radius_tiles + tiles_per_chunk):
						macro_noise = port_ground_noise_target
						break
			
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
	
	var base_noise = _noise.get_noise_2d(global_x, global_y)
	
	var inside_directional_cutoff := false
	
	for struct in _all_structures:
		if struct.influence_type == PlacedStructure.InfluenceType.NONE:
			continue
			
		var v_struct = current_point - struct.tile_position
		var dist = v_struct.length()
		
		if struct.influence_type == PlacedStructure.InfluenceType.CIRCLE:
			if dist < struct.land_radius_tiles:
				var factor = 1.0 - (dist / struct.land_radius_tiles)
				return lerp(base_noise, port_ground_noise_target, factor)
				
		elif struct.influence_type == PlacedStructure.InfluenceType.DIRECTIONAL:
			var is_behind = v_struct.dot(struct.land_direction.normalized()) > 0.0
			if is_behind:
				if dist < struct.land_radius_tiles:
					var factor = 1.0 - (dist / struct.land_radius_tiles)
					return lerp(base_noise, port_ground_noise_target, factor)
				inside_directional_cutoff = true
				
	if inside_directional_cutoff:
		return base_noise
		
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
	
	var handle_len = path_length * path_length_multiplier_for_deviation 
	
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
	
	curve.bake_interval = curve_bake_interval
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

func _spawn_structures() -> void:
	var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
	
	for struct in _all_structures:
		if struct.scene:
			var instance = struct.scene.instantiate() as Node2D
			instance.position = struct.tile_position * tile_size
			add_child(instance)

func _randomize_ports() -> void:
	var max_x = (grid_width * tiles_per_chunk) - path_margin_tiles
	var max_y = (grid_height * tiles_per_chunk) - path_margin_tiles
	var min_coord = path_margin_tiles
	
	var valid_positions = false
	var attempts = 0
	
	while not valid_positions and attempts < number_of_attempts_for_random_path:
		start_pos_tiles = Vector2(randf_range(min_coord, max_x), randf_range(min_coord, max_y))
		end_pos_tiles = Vector2(randf_range(min_coord, max_x), randf_range(min_coord, max_y))
		
		if start_pos_tiles.distance_to(end_pos_tiles) >= min_path_length_tiles:
			valid_positions = true
			
		attempts += 1

	if not valid_positions:
		start_pos_tiles = Vector2(min_coord, min_coord)
		end_pos_tiles = Vector2(max_x, max_y)
		print("Warning: Map too small for min_path_length. Forcing corners.")
