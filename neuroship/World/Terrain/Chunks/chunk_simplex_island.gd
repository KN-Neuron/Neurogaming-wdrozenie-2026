extends ChunkBaseTerrain

const SAND_TILE := Vector2i(1, 0)
const GRASS_TILE := Vector2i(6, 0)
const DARK_GRASS_TILE := Vector2i(6, 1)
const WATER_TILE := Vector2i(8, 0)

func _get_tile_from_noise(noise_value: float) -> Vector2i:
	if noise_value < 0.0:
		return WATER_TILE
	elif noise_value >= 0.0 and noise_value < 0.3:
		return SAND_TILE
	elif noise_value >= 0.3 and noise_value < 0.5:
		return GRASS_TILE
	else:
		return DARK_GRASS_TILE
