extends Node2D

const STAR_TILES: int = 3

var scroll_speed = 0; # Set by the map
onready var back_layer1: Sprite = $Back1
onready var tile_layer1: TileMap = $TileLayer1
onready var tile_layer2: TileMap = $TileLayer2
onready var tile_layer3: TileMap = $TileLayer3

var tile1_pos: Vector2 = Vector2.ZERO
var tile2_pos: Vector2 = Vector2.ZERO
var tile3_pos: Vector2 = Vector2.ZERO

var tiles_parallax: Array = []
var stars_grid: CuteGrid;

func _ready():
	tiles_parallax.append({map = $TileLayer1, pos = Vector2.ZERO, speed = 1.25})
	tiles_parallax.append({map = $TileLayer2, pos = Vector2.ZERO, speed = 0.9})
	tiles_parallax.append({map = $TileLayer3, pos = Vector2.ZERO, speed = 0.65})

	stars_grid = CuteGrid.new(tiles_parallax[0].map.get_cell_size().x, Vector2(Game.SCREEN_WIDTH*2, Game.SCREEN_HEIGHT))
	
	for i in range(tiles_parallax.size()):
		tiles_parallax[i].map.clear()
		generate_stars_in_tiles(i)


func generate_stars_in_tiles(index: int, offset: Vector2 = Vector2.ZERO):
	stars_grid.clear_grid()
	stars_grid.fill_with_random_vals([0, 1, 2], 0.05)
	stars_grid.map_into_tilemap(tiles_parallax[index].map, offset)
	tiles_parallax[index].map.update_bitmask_region();

func _process(delta):
	back_layer1.position += Vector2(-scroll_speed*delta, 0.0);
	if (back_layer1.position.x <= -Game.SCREEN_WIDTH):
		back_layer1.position.x += Game.SCREEN_WIDTH;

	for i in range(tiles_parallax.size()):
		var delta_mov: Vector2 = Vector2(-scroll_speed*delta*tiles_parallax[i].speed, 0.0)
		tiles_parallax[i].map.position+=delta_mov
		tiles_parallax[i].pos+=delta_mov
		
		if (tiles_parallax[i].pos.x <= -Game.SCREEN_WIDTH):
			var mult: int = int(round(abs(tiles_parallax[i].map.position.x/Game.SCREEN_WIDTH)))
			var cell_offset: Vector2 = mult*tiles_parallax[i].map.world_to_map(Vector2(Game.SCREEN_WIDTH, 0))*2
			tiles_parallax[i].pos.x += Game.SCREEN_WIDTH;
			generate_stars_in_tiles(i, cell_offset)
