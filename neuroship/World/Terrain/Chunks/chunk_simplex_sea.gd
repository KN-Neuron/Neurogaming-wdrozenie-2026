extends Node2D

@export var terrain_tile_map_layer: TileMapLayer

@export var map_width: int = 16
@export var map_height: int = 16

const WATER_TILE := Vector2i(8, 0)
const DEEP_WATER_TILE := Vector2i(8, 1)

const SOURCE_ID := 0

func generate_terrain_from_noise(global_noise: FastNoiseLite, chunk_grid_pos: Vector2i) -> void:
	if not terrain_tile_map_layer:
		printerr("No TileMapLayer assigned for sea terrain. Cannot generate terrain.")
		return

	terrain_tile_map_layer.clear()
	
	for x in range(map_width):
		for y in range(map_height):

			var global_x = (chunk_grid_pos.x * map_width) + x
			var global_y = (chunk_grid_pos.y * map_height) + y

			var noise_value: float = global_noise.get_noise_2d(global_x, global_y) # [-1, 1]
			var selected_tile: Vector2i

			if noise_value < 0.45:
				selected_tile = WATER_TILE
			else:
				selected_tile = DEEP_WATER_TILE
			
			terrain_tile_map_layer.set_cell(Vector2i(x, y), SOURCE_ID, selected_tile)
