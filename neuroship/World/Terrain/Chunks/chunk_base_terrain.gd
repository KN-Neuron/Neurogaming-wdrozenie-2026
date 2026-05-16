class_name ChunkBaseTerrain
extends Node2D

@export var terrain_tile_map_layer: TileMapLayer
@export var chunk_width: int = 16
@export var chunk_height: int = 16

const SOURCE_ID := 0

func generate_terrain_from_noise(noise_function: Callable, chunk_grid_pos: Vector2i) -> void:
    if not terrain_tile_map_layer:
        printerr("No TileMapLayer assigned. Cannot generate terrain.")
        return

    terrain_tile_map_layer.clear()
    
    for x in range(chunk_width):
        for y in range(chunk_height):
            var global_x = (chunk_grid_pos.x * chunk_width) + x
            var global_y = (chunk_grid_pos.y * chunk_height) + y

            var noise_value: float = noise_function.call(global_x, global_y)
            
            var selected_tile: Vector2i = _get_tile_from_noise(noise_value)
            
            terrain_tile_map_layer.set_cell(Vector2i(x, y), SOURCE_ID, selected_tile)

func _get_tile_from_noise(_noise_value: float) -> Vector2i:
    return Vector2i.ZERO