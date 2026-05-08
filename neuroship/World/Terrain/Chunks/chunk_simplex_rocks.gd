extends Node2D

@export var terrain_tile_map_layer: TileMapLayer

@export var map_width: int = 16
@export var map_height: int = 16
@export var noise_seed: int = randi()
@export var noise_frequency: float = 0.05

var _noise: FastNoiseLite

const ROCK_TILE := Vector2i(7, 0)
const HARD_ROCK_TILE := Vector2i(7, 1)
const WATER_TILE := Vector2i(8, 0)
const DEEP_WATER_TILE := Vector2i(8, 1)

const SOURCE_ID := 0

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency

	generate_terrain()

func generate_terrain() -> void:
	if not terrain_tile_map_layer:
		printerr("No TileMapLayer assigned for rock terrain. Cannot generate terrain.")
		return

	terrain_tile_map_layer.clear()

	for x in range(map_width):
		for y in range(map_height):
			var noise_value: float = _noise.get_noise_2d(x, y) # [-1, 1]
			var selected_tile: Vector2i

			if noise_value < -0.2:
				selected_tile = ROCK_TILE
			elif noise_value >= -0.2 and noise_value < 0.1:
				selected_tile = HARD_ROCK_TILE
			else:
				selected_tile = WATER_TILE


			terrain_tile_map_layer.set_cell(Vector2i(x, y), SOURCE_ID, selected_tile)
