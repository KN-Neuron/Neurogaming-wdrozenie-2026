class_name PlacedStructure
extends Resource

enum InfluenceType { NONE, CIRCLE, DIRECTIONAL }
enum PlacementMethod { FIXED, RANDOM }

@export var structure_name: String = "Structure"
@export var scene: PackedScene

@export_group("Placement")
@export var placement_method: PlacementMethod = PlacementMethod.FIXED
@export var tile_position: Vector2 = Vector2.ZERO
@export var random_spawn_count_min: int = 1
@export var random_spawn_count_max: int = 3

@export_group("Spawn Conditions")
@export var restrict_spawn_by_noise: bool = false
@export var allowed_noise_min: float = -1.0
@export var allowed_noise_max: float = 1.0

@export_group("Influence")
@export var influence_radius_tiles: float = 22.5
@export var target_noise: float = 0.4
@export var influence_type: InfluenceType = InfluenceType.CIRCLE
@export var influence_direction: Vector2 = Vector2.UP
