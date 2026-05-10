extends ChunkBaseTerrain

const ROCK_TILE := Vector2i(7, 0)
const HARD_ROCK_TILE := Vector2i(7, 1)
const WATER_TILE := Vector2i(8, 0)
const DEEP_WATER_TILE := Vector2i(8, 1)

func _get_tile_from_noise(noise_value: float) -> Vector2i:
	if noise_value < 0.5:
		return WATER_TILE
	elif noise_value >= 0.5 and noise_value < 0.8:
		return ROCK_TILE
	else:
		return HARD_ROCK_TILE
			
