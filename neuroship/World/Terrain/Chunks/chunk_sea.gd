extends ChunkBaseTerrain

const WATER_TILE := Vector2i(8, 0)
const DEEP_WATER_TILE := Vector2i(8, 1)

func _get_tile_from_noise(noise_value: float) -> Vector2i:
	if noise_value < 0.45:
		return WATER_TILE
	else:
		return DEEP_WATER_TILE
