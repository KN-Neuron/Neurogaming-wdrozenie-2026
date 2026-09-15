extends Node2D

@export_group("Debug")
@export var debug_mode: bool = false

@export_group("Player")
@export var player_ship_scene: PackedScene

@export_group("Structures")
@export var start_port_scene: PackedScene
@export var end_port_scene: PackedScene
@export var port_ground_noise_target: float = 0.4
@export var port_land_cap_multiplier: float = 1.5
@export var additional_structures: Array[PlacedStructure] = []
@export var max_valid_structure_spawn_attempts: int = 50

@export_group("Path")
@export var randomize_path: bool = true
@export var min_path_length_tiles: float = 400.0
@export var path_margin_tiles: float = 50.0
@export var path_length_multiplier_for_deviation: float = 0.25
@export var curve_bake_interval: float = 20.0
@export var max_random_path_attempts: int = 100
@export var river_curve_point_one_ratio: float = 0.33
@export var river_curve_point_two_ratio: float = 0.66

@export var start_pos_tiles: Vector2 = Vector2(10, 10)
@export var end_pos_tiles: Vector2 = Vector2(300, 300)
@export var path_width_tiles: float = 15.0
@export var max_path_deviation: float = 80.0

var _baked_river_path: PackedVector2Array
var _river_bounds: Rect2
var _segment_bounds: Array[Rect2]
var _all_structures: Array[PlacedStructure] = []
var _noise: FastNoiseLite
var _rng: RandomNumberGenerator

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

func _ready() -> void:
	# Cleanup debug tools if not needed
	if not debug_mode:
		$Camera2D.queue_free()

	# Init random seed
	_rng = RandomNumberGenerator.new()
	if use_random_seed:
		_rng.randomize()
		world_seed = _rng.seed
	else:
		_rng.seed = world_seed

	print("Generated world seed: ", world_seed)

	# Setup simplex noise
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency

	# Execute world generation pipeline
	if randomize_path:
		_randomize_ports()

	_generate_river_curve()
	_initialize_structures()
	
	# Sort biomes for waterfall logic
	biomes.sort_custom(func(a, b): return a.upper_threshold < b.upper_threshold)

	await generate_chunk_map()
	_spawn_structures()

	_spawn_player()

	# Focus camera on start port
	if debug_mode:
		var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
		$Camera2D.position = start_pos_tiles * tile_size
		$Camera2D.make_current()

func _initialize_structures() -> void:
	# Combine built-in ports and custom structures into a single array
	_all_structures.clear()
	
	var total_path_vector: Vector2 = end_pos_tiles - start_pos_tiles
	var main_path_dir: Vector2 = total_path_vector.normalized()
	var land_cap_radius: float = path_width_tiles * port_land_cap_multiplier

	# Auto-configure start port logic
	if start_port_scene:
		var start_struct: PlacedStructure = PlacedStructure.new()
		start_struct.structure_name = "Start Port"
		start_struct.scene = start_port_scene
		start_struct.tile_position = start_pos_tiles
		start_struct.influence_radius_tiles = land_cap_radius
		start_struct.target_noise = port_ground_noise_target
		start_struct.influence_type = PlacedStructure.InfluenceType.DIRECTIONAL
		start_struct.influence_direction = -main_path_dir
		_all_structures.append(start_struct)
		
	# Auto-configure end port logic
	if end_port_scene:
		var end_struct: PlacedStructure = PlacedStructure.new()
		end_struct.structure_name = "End Port"
		end_struct.scene = end_port_scene
		end_struct.tile_position = end_pos_tiles
		end_struct.influence_radius_tiles = land_cap_radius
		end_struct.target_noise = port_ground_noise_target
		end_struct.influence_type = PlacedStructure.InfluenceType.DIRECTIONAL
		end_struct.influence_direction = main_path_dir
		_all_structures.append(end_struct)
		
	# Append custom structures
	for struct in additional_structures:
		if not struct:
			continue
			
		if struct.placement_method == PlacedStructure.PlacementMethod.FIXED:
			_all_structures.append(struct)
		else:
			var spawn_count: int = _rng.randi_range(struct.random_spawn_count_min, struct.random_spawn_count_max)

			var min_coord: float = path_margin_tiles
			var max_x: float = (grid_width * tiles_per_chunk) - path_margin_tiles
			var max_y: float = (grid_height * tiles_per_chunk) - path_margin_tiles

			for i in range(spawn_count):
				var valid_spot_found: bool = false
				var attempts: int = 0
				var random_x: float = 0.0
				var random_y: float = 0.0

				while not valid_spot_found and attempts < max_valid_structure_spawn_attempts:
					random_x = _rng.randf_range(min_coord, max_x)
					random_y = _rng.randf_range(min_coord, max_y)

					if struct.restrict_spawn_by_noise:
						var current_terrain_noise: float = _get_world_noise(random_x, random_y)
						if current_terrain_noise >= struct.allowed_noise_min and current_terrain_noise <= struct.allowed_noise_max:
							valid_spot_found = true
					else:
						valid_spot_found = true

					attempts += 1

				if valid_spot_found:
					var random_struct: PlacedStructure = struct.duplicate() as PlacedStructure
					random_struct.tile_position = Vector2(random_x, random_y)
					_all_structures.append(random_struct)
				else:
					push_warning("Could not find valid spawn for ", struct.structure_name, " after ", max_valid_structure_spawn_attempts, " attempts.")

func generate_chunk_map() -> void:
	# Clear old chunks before generating new ones
	for child in get_children():
		if child is ChunkBaseTerrain:
			child.queue_free()

	if biomes.is_empty():
		push_error("No biomes provided. Cannot generate terrain.")
		return

	# Generate grid
	const CHUNKS_PER_FRAME := 50
	var chunks_since_yield := 0

	for x in range(grid_width):
		for y in range(grid_height):
			var center_tile_x: int = (x * tiles_per_chunk) + int(tiles_per_chunk / 2.0)
			var center_tile_y: int = (y * tiles_per_chunk) + int(tiles_per_chunk / 2.0)

			var chunk_center_tiles: Vector2 = Vector2(center_tile_x, center_tile_y)
			var macro_noise: float = _get_world_noise(center_tile_x, center_tile_y)
			macro_noise = _get_structure_override_noise(chunk_center_tiles, macro_noise)

			var chunk_instance: Node2D = null

			# Waterfall biome selection
			for biome in biomes:
				if macro_noise <= biome.upper_threshold:
					if not biome.chunk_scenes.is_empty():
						chunk_instance = biome.chunk_scenes[_rng.randi_range(0, biome.chunk_scenes.size() - 1)].instantiate() as Node2D
					break

			# Failsafe: assign the highest threshold biome
			if not chunk_instance:
				var fallback_biome: BiomeData = biomes[biomes.size() - 1]
				if not fallback_biome.chunk_scenes.is_empty():
					push_warning("No biome found for noise value ", macro_noise, " at chunk (", x, ", ", y, "). Using default biome.")
					chunk_instance = fallback_biome.chunk_scenes[_rng.randi_range(0, fallback_biome.chunk_scenes.size() - 1)].instantiate() as Node2D
				else:
					push_error("Fallback biome '", fallback_biome.biome_name, "' has no chunk_scenes. Skipping chunk (", x, ", ", y, ").")
					continue

			# Position and initialize chunk
			chunk_instance.position = Vector2(x, y) * chunk_size_pixels
			if chunk_instance is ChunkBaseTerrain:
				chunk_instance.generate_terrain_from_noise(_get_world_noise, Vector2i(x, y))

			add_child(chunk_instance)

			chunks_since_yield += 1
			if chunks_since_yield >= CHUNKS_PER_FRAME:
				chunks_since_yield = 0
				await get_tree().process_frame

func _get_structure_override_noise(chunk_center_tiles: Vector2, default_noise: float) -> float:
	for struct in _all_structures:
		if struct.influence_type == PlacedStructure.InfluenceType.NONE:
			continue

		var dist: float = chunk_center_tiles.distance_to(struct.tile_position)
		if dist < (struct.influence_radius_tiles + tiles_per_chunk):
			return struct.target_noise

	return default_noise

func _get_world_noise(global_x: float, global_y: float) -> float:
	var current_point: Vector2 = Vector2(global_x, global_y)
	var base_noise: float = _noise.get_noise_2d(global_x, global_y)
	var inside_directional_cutoff := false

	# Apply terrain modifications from structures (always, regardless of river bounds)
	for struct in _all_structures:
		if struct.influence_type == PlacedStructure.InfluenceType.NONE:
			continue

		var vector_to_structure: Vector2 = current_point - struct.tile_position
		var dist: float = vector_to_structure.length()

		# Circular influence
		if struct.influence_type == PlacedStructure.InfluenceType.CIRCLE:
			if dist < struct.influence_radius_tiles:
				var factor: float = 1.0 - (dist / struct.influence_radius_tiles)
				return lerp(base_noise, struct.target_noise, factor)

		# Directional influence
		elif struct.influence_type == PlacedStructure.InfluenceType.DIRECTIONAL:
			var is_behind: bool = vector_to_structure.dot(struct.influence_direction.normalized()) > 0.0
			if is_behind:
				if dist < struct.influence_radius_tiles:
					var factor: float = 1.0 - (dist / struct.influence_radius_tiles)
					return lerp(base_noise, struct.target_noise, factor)
				inside_directional_cutoff = true

	# Ignore river carving if standing behind a directional structure
	if inside_directional_cutoff:
		return base_noise

	# Fast exit if point is far from the river
	if not _river_bounds.has_point(current_point):
		return base_noise

	# Find distance to the closest river segment
	var min_distance_sq: float = INF
	var path_width_sq: float = path_width_tiles * path_width_tiles
	var is_near_any_segment: bool = false

	# Segment optimization check
	for i in range(_segment_bounds.size()):
		if _segment_bounds[i].has_point(current_point):
			is_near_any_segment = true
			var p1: Vector2 = _baked_river_path[i]
			var p2: Vector2 = _baked_river_path[i+1]
			var closest_pt: Vector2 = Geometry2D.get_closest_point_to_segment(current_point, p1, p2)

			var dist_sq: float = current_point.distance_squared_to(closest_pt)
			if dist_sq < min_distance_sq:
				min_distance_sq = dist_sq

	# Carve river into the terrain
	if is_near_any_segment and min_distance_sq < path_width_sq:
		var actual_distance: float = sqrt(min_distance_sq)
		var mask_strength: float = actual_distance / path_width_tiles
		var carved_noise: float = lerp(-1.0, base_noise, mask_strength)
		return min(base_noise, carved_noise)
		
	return base_noise

func _generate_river_curve() -> void:
	# Create an S-shaped path between start and end
	var curve: Curve2D = Curve2D.new()

	var path_vector: Vector2 = end_pos_tiles - start_pos_tiles
	var path_length: float = path_vector.length()
	var path_dir: Vector2 = path_vector.normalized()
	var path_normal: Vector2 = Vector2(-path_dir.y, path_dir.x)

	var handle_len: float = path_length * path_length_multiplier_for_deviation

	# Randomize curve control points
	var midpoint_first: float = _rng.randf_range(max_path_deviation * 0.5, max_path_deviation)
	if _rng.randi() % 2 == 0:
		midpoint_first = -midpoint_first

	var midpoint_second: float = _rng.randf_range(max_path_deviation * 0.5, max_path_deviation)
	if midpoint_first > 0:
		midpoint_second = -midpoint_second

	# Plot points
	curve.add_point(start_pos_tiles)

	var point_one: Vector2 = start_pos_tiles + (path_vector * river_curve_point_one_ratio)
	curve.add_point(point_one + (path_normal * midpoint_first), -path_dir * handle_len, path_dir * handle_len)

	var point_two: Vector2 = start_pos_tiles + (path_vector * river_curve_point_two_ratio)
	curve.add_point(point_two + (path_normal * midpoint_second), -path_dir * handle_len, path_dir * handle_len)
	
	curve.add_point(end_pos_tiles)
	
	# Bake points for faster runtime distance checking
	curve.bake_interval = curve_bake_interval
	_baked_river_path = curve.get_baked_points()
	
	# Generate bounding boxes for distance optimization
	_river_bounds = Rect2(start_pos_tiles, Vector2.ZERO)
	_segment_bounds.clear()
	
	for i in range(_baked_river_path.size()):
		var p: Vector2 = _baked_river_path[i]
		_river_bounds = _river_bounds.expand(p)

		if i < _baked_river_path.size() - 1:
			var p_next: Vector2 = _baked_river_path[i+1]
			var seg_rect: Rect2 = Rect2(p, Vector2.ZERO).expand(p_next)
			_segment_bounds.append(seg_rect.grow(path_width_tiles + 2.0))
			
	_river_bounds = _river_bounds.grow(path_width_tiles + 2.0)

func _spawn_structures() -> void:
	# Instantiate structured objects onto the map
	var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
	
	for struct in _all_structures:
		if struct.scene:
			var instance: Node2D = struct.scene.instantiate() as Node2D
			instance.position = struct.tile_position * tile_size
			add_child(instance)

func _randomize_ports() -> void:
	# Keep looking for random positions until minimum distance is met
	var max_x: float = (grid_width * tiles_per_chunk) - path_margin_tiles
	var max_y: float = (grid_height * tiles_per_chunk) - path_margin_tiles
	var min_coord: float = path_margin_tiles

	var valid_positions: bool = false
	var attempts: int = 0
	
	while not valid_positions and attempts < max_random_path_attempts:
		start_pos_tiles = Vector2(_rng.randf_range(min_coord, max_x), _rng.randf_range(min_coord, max_y))
		end_pos_tiles = Vector2(_rng.randf_range(min_coord, max_x), _rng.randf_range(min_coord, max_y))
		
		if start_pos_tiles.distance_to(end_pos_tiles) >= min_path_length_tiles:
			valid_positions = true
			
		attempts += 1

	# Failsafe: Use corners if map is too small
	if not valid_positions:
		start_pos_tiles = Vector2(min_coord, min_coord)
		end_pos_tiles = Vector2(max_x, max_y)
		push_warning("Map too small for min_path_length. Forcing corners.")

func _spawn_player() -> void:
	if not player_ship_scene:
		push_error("Player ship scene is not assigned")
		return
		
	var tile_size: float = chunk_size_pixels.x / float(tiles_per_chunk)
	var ship_instance: Node2D = player_ship_scene.instantiate() as Node2D

	var target_distance_tiles: float = 15.0
	var spawn_tile: Vector2 = start_pos_tiles
	var forward_dir: Vector2 = Vector2.UP

	if _baked_river_path.size() > 1:
		for i in range(1, _baked_river_path.size()):
			var current_pt: Vector2 = _baked_river_path[i]
			
			if start_pos_tiles.distance_to(current_pt) >= target_distance_tiles:
				spawn_tile = current_pt
				forward_dir = (current_pt - _baked_river_path[i - 1]).normalized()
				break
	
	ship_instance.position = spawn_tile * tile_size
	ship_instance.rotation = forward_dir.angle()
	
	add_child(ship_instance)
