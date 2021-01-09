extends Node2D

const STAR_TILES: int = 3
const ASTEROIDS_TO_SPAWN_MIN: int = 30
const ASTEROIDS_TO_SPAWN_MAX: int = 70

var scroll_speed = 0; # Set by the map
onready var back_layer1: Sprite = $Back1
var stars_tiles: Array = []
var tiles_indexes: Array
var stars_grid: CuteGrid;
var foreground_asteroid_scene: PackedScene = preload("res://scenes/ForegroundAsteroid.tscn")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

signal speed_updated(new_speed)

func _ready():
	rng.randomize()
	init_stars()
	spawn_foreground_asteroids()
	
func init_stars(): #Parallax background init
	tiles_indexes.clear()
	for i in STAR_TILES:
		tiles_indexes.append(i)
		
	stars_tiles.append({map = $stars1, pos = Vector2.ZERO, speed = 0.3})
	stars_tiles.append({map = $stars1_anim, pos = Vector2.ZERO, speed = 0.25})
	stars_tiles.append({map = $stars2, pos = Vector2.ZERO, speed = 0.2})
	stars_tiles.append({map = $stars2_anim, pos = Vector2.ZERO, speed = 0.15})
	stars_tiles.append({map = $stars3, pos = Vector2.ZERO, speed = 0.1})
	stars_tiles.append({map = $stars3_anim, pos = Vector2.ZERO, speed = 0.05})
	
	stars_grid = CuteGrid.new(stars_tiles[0].map.get_cell_size().x, Vector2(Game.SCREEN_WIDTH*2, Game.SCREEN_HEIGHT))
	for i in range(stars_tiles.size()):
		stars_tiles[i].map.clear()
		generate_stars_in_tiles(i)

func spawn_foreground_asteroids(): #aren't these background asteroids?, english bad with me
	var foreground_asteroids_to_spawn: int = rand_range(ASTEROIDS_TO_SPAWN_MIN, ASTEROIDS_TO_SPAWN_MAX)
	for i in foreground_asteroids_to_spawn:
		var foreground_asteroid: Node2D = foreground_asteroid_scene.instance()
		foreground_asteroid.base_velocity = Vector2(-scroll_speed, 0.0)
		connect("speed_updated", foreground_asteroid, "_on_speed_updated")
		$Asteroids1.add_child(foreground_asteroid)


func generate_stars_in_tiles(index: int, offset: Vector2 = Vector2.ZERO):
	stars_grid.clear_grid()
	stars_grid.fill_with_random_vals(tiles_indexes, rng.randf_range(0.01, 0.05))
	stars_grid.map_into_tilemap(stars_tiles[index].map, offset)
	stars_tiles[index].map.update_bitmask_region();

func _process(delta):
	back_layer1.position += Vector2(-scroll_speed*delta, 0.0);
	if (back_layer1.position.x <= -Game.SCREEN_WIDTH):
		back_layer1.position.x += Game.SCREEN_WIDTH;
	move_all_stars(delta)

func move_all_stars(delta):
	for i in range(stars_tiles.size()):
		move_stars_layer(delta, i)

func move_stars_layer(delta: float, layer_index: int):
	var delta_mov: Vector2 = Vector2(-scroll_speed*delta*stars_tiles[layer_index].speed, 0.0)
	stars_tiles[layer_index].map.position+=delta_mov
	stars_tiles[layer_index].pos+=delta_mov
		
	if (stars_tiles[layer_index].pos.x <= -Game.SCREEN_WIDTH):
		var tile_map_end_cell: Vector2 = stars_tiles[layer_index].map.world_to_map(Vector2(Game.SCREEN_WIDTH, 0))
		var cell_offset: Vector2 = stars_tiles[layer_index].map.world_to_map(Vector2(-stars_tiles[layer_index].map.position.x, 0))
		stars_tiles[layer_index].pos.x += Game.SCREEN_WIDTH;
		for x in range(cell_offset.x - tile_map_end_cell.x, cell_offset.x):
			for y in range(stars_grid.get_grid_size().y):
				stars_tiles[layer_index].map.set_cell(x, y, -1)
		generate_stars_in_tiles(layer_index, cell_offset+tile_map_end_cell)

func _on_level_speed_changed(new_speed: Vector2):
	scroll_speed = new_speed.x
	emit_signal("speed_updated", new_speed)
