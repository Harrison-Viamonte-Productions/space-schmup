class_name CuteGrid #It's called cute because I am working with my best friend matthew so I am happy.
extends Object

# This object exits because you can't pass arrays as reference in godot
# but objects yes, so this object it's going to be the CuteGrid

const GRID_NULL: int = -1;

# Cardinal bitflags, really useful.
const N: int = 0x1;
const NE: int = 0x2;
const E: int = 0x4;
const SE: int = 0x8;
const S: int = 0x16;
const SW: int = 0x32;
const W: int = 0x64;
const NW: int = 0x128;

# Shorthand for getting Neighbors
const ALL_DIR: int = N | NE | E | SE | S | SW | W | NW; # All 8 directions
const DIAG_DIR: int = NE | SE | SW | NW; # Diagonal directions only
const HOR_AND_VER_DIR: int = ALL_DIR - DIAG_DIR; # Horizontal and vertical directions

var cell_dirs: Dictionary = { # The keys are vectors 2D, which is awesome and handy
	Vector2(0, -1): N,
	Vector2(1, -1): NE,
	Vector2(1, 0): E,
	Vector2(1, 1): SE,
	Vector2(0, 1): S,
	Vector2(-1, 1): SW,
	Vector2(-1, 0): W,
	Vector2(-1, -1): NW
};

var _grid: Array = [];
var _cell_size: int = 0;
var _dimensions_world: Vector2 = Vector2.ZERO; # Dimensions of the grid but in pixels

#TODO for other project: Allow CuteGrid to be binded with a TileMap node

# Square grids only by now (not infinite... :( )
func _init(cell_size: int, dimensions_world: Vector2):
	assert(cell_size > 0);
	_cell_size = cell_size;
	_dimensions_world = dimensions_world;
	clear_grid();

func get_dimension() -> Vector2:
	return Vector2(int(floor(_dimensions_world.x/_cell_size)), int(floor(_dimensions_world.y/_cell_size)));

func get_grid_size() -> Vector2:
	if _grid.size() > 0:
		return Vector2(_grid.size(), _grid[0].size());
	else:
		return Vector2.ZERO;

func get_cell_from_world_pos(pos_world: Vector2) -> Vector2:
	return Vector2(int(floor(pos_world.x/_cell_size)), int(floor(pos_world.y/_cell_size)));

func get_world_pos_from_cell(cell: Vector2) -> Vector2:
	return cell*_cell_size;

func get_world_pos_from_cell_centered(cell: Vector2) -> Vector2:
	return Vector2(0.5*_cell_size*(2.0*cell.x+1),  0.5*_cell_size*(2.0*cell.y+1));

func get_cellv(cell: Vector2):
	return _grid[cell.x][cell.y];

func set_cellv(cell: Vector2, val):
	_grid[cell.x][cell.y] = val;

func is_in_bounds(cell: Vector2) -> bool:
	if _grid.empty():
		return false;
	if (cell.x >= _grid.size() or cell.y >= _grid[cell.x].size()) or (cell.x < 0 or cell.y < 0):
		return false;
	else:
		return true;

func get_neighbors(cell: Vector2, bit_mask: int = ALL_DIR) -> Array: # Return an array with the cells (vector2) of the valid neighbors, sanitazed taking in account dimension bounds
	if !is_in_bounds(cell):
		print("[WARNING] using get_neighbors with a cell that does not exists in the CuteGrid map!")
		return [];

	var neighbors: Array = [];
	for dir in cell_dirs.keys():
		if (cell_dirs[dir] & bit_mask) and is_in_bounds(cell+dir):
			neighbors.append(cell+dir);
	return neighbors;

func filter_cells_by_val(val) -> Array: # Returns an array of vector2 with all the cells that have some specific value
	var cells: Array = [];
	var grid_size: Vector2 = get_grid_size();
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			if _grid[x][y] == val:
				cells.append(Vector2(x, y));
	return cells;

#this one does not allow dinamic update, just literally clears the whole grid
func set_cell_size(new_cell_size: int) -> void:
	_cell_size = new_cell_size;
	clear_grid();

# Allows dinamic resize of the grid while keeping the original tiles.
func set_dimension_world(dim_world: Vector2, clear: bool = false, fill_with = GRID_NULL) -> void:
	_dimensions_world = dim_world;
	
	if clear:
		clear_grid(fill_with);
		return;
		
	var new_grid_dimension: Vector2 = get_dimension();
	# Dinamically adapt to the new size while keeping original values
	for x in range(int(max(_grid.size(), new_grid_dimension.x))):
		if x >= new_grid_dimension.x:
			_grid.pop_back();
			continue;
		elif x >= _grid.size():
			_grid.append([]);
		for y in range(int(max(_grid[x].size(), new_grid_dimension.y))):
			if y >= new_grid_dimension.y:
				_grid[x].pop_back();
			elif y >= _grid[x].size():
				_grid[x].append(fill_with);

func get_random_cell(force_seed: int = -1) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();
	var dim: Vector2 = get_dimension();
	if force_seed != -1:
		rng.set_seed(force_seed);
	return Vector2(rng.randi_range(0, dim.x-1), rng.randi_range(0, dim.y-1));

######################
# To draw the grid, in a _draw method use for each line in lines, being lines what get_lines return
#	draw_line(line[0], line[1], Color(0, 0, 255), 1);
#####################

func get_lines() -> Array: #An array of all the lines needed to draw the grid using draw_line function
	var lines: Array = [];
	var grid_dimension: Vector2 = get_dimension();
	for x in range(int(grid_dimension.x)):
		for y in range(int(grid_dimension.y)):
			lines.append([Vector2(x*_cell_size, y*_cell_size), Vector2(x*_cell_size, (y+1)*_cell_size)]);
			lines.append([Vector2(x*_cell_size, y*_cell_size), Vector2((x+1)*_cell_size, y*_cell_size)]);
			lines.append([Vector2((x+1)*_cell_size, y*_cell_size), Vector2((x+1)*_cell_size, (y+1)*_cell_size)]);
			lines.append([Vector2(x*_cell_size, (y+1)*_cell_size), Vector2((x+1)*_cell_size, (y+1)*_cell_size)]);
	return lines;

func clear_grid(fill_with = GRID_NULL) -> void:
	_grid.clear();
	var grid_dimension: Vector2 = get_dimension();
	for x in range(int(grid_dimension.x)):
		_grid.append([]);
		for y in range(int(grid_dimension.y)):
			_grid[x].append(fill_with);
