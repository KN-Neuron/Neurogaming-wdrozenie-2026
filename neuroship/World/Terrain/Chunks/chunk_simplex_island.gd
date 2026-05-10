extends Node2D

@export var terrain_tile_map_layer: TileMapLayer

@export var chunk_width: int = 16
@export var chunk_height: int = 16

const SAND_TILE := Vector2i(1, 0)
const GRASS_TILE := Vector2i(6, 0)
const DARK_GRASS_TILE := Vector2i(6, 1)
const WATER_TILE := Vector2i(8, 0)

const SOURCE_ID := 0

func generate_terrain_from_noise(global_noise: FastNoiseLite, chunk_grid_pos: Vector2i) -> void:
	if not terrain_tile_map_layer:
		printerr("No TileMapLayer assigned for island terrain. Cannot generate terrain.")
		return

	terrain_tile_map_layer.clear()

	for x in range(chunk_width):
		for y in range(chunk_height):
			
			var global_x = (chunk_grid_pos.x * chunk_width) + x
			var global_y = (chunk_grid_pos.y * chunk_height) + y

			var noise_value: float = global_noise.get_noise_2d(global_x, global_y) # [-1, 1]
			var selected_tile: Vector2i

			if noise_value < 0.0:
				selected_tile = WATER_TILE
			elif noise_value >= 0.0 and noise_value < 0.3:
				selected_tile = SAND_TILE
			elif noise_value >= 0.3 and noise_value < 0.5:
				selected_tile = GRASS_TILE
			else:
				selected_tile = DARK_GRASS_TILE

			terrain_tile_map_layer.set_cell(Vector2i(x, y), SOURCE_ID, selected_tile)
