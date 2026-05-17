class_name PlacedStructure
extends Resource

enum InfluenceType { NONE, CIRCLE, DIRECTIONAL }

@export var structure_name: String = "Structure"
@export var scene: PackedScene
@export var tile_position: Vector2 = Vector2.ZERO

@export var influence_radius_tiles: float = 22.5
@export var target_noise: float = 0.4

@export var influence_type: InfluenceType = InfluenceType.CIRCLE
@export var influence_direction: Vector2 = Vector2.UP
