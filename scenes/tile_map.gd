extends TileMap

signal end_game
signal game_won
signal flag_placed
signal flag_removed

#grid variables
const ROWS : int = 14
const COLS : int = 15
const CELL_SIZE : int = 50

#tilemap variables
var tile_id : int = 0

#layer variables
var mine_layer : int = 0
var number_layer : int = 1
var grass_layer : int = 2
var flag_layer : int = 3
var hover_layer : int = 4

#atlas coordinates
var mine_atlas := Vector2i(4, 0)
var flag_atlas := Vector2i(5, 0)
var hover_atlas := Vector2i(6, 0)
var number_atlas : Array = generate_number_atlas()

#array to store mine coordinates
var mine_coords := []

#toggle variable to scan nearby mines
var scanning := false

func generate_number_atlas():
	var a := []
	for i in range(8):
		a.append(Vector2i(i, 1))
	return a

# Called when the node enters the scene tree for the first time.
func _ready():
	new_game()
	
#reset game
func new_game():
	clear()
	mine_coords.clear()
	generate_mines()
	generate_numbers()
	generate_grass()
	
func generate_mines():
	for i in range(get_parent().TOTAL_MINES):
		var mine_pos = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		while mine_coords.has(mine_pos):
			mine_pos = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		mine_coords.append(mine_pos)
		#add mine to tilemap
		set_cell(mine_layer, mine_pos, tile_id, mine_atlas)

func generate_numbers():
	#clear previous numbers in case the mine was moved
	clear_layer(number_layer)
	for i in get_empty_cells():
		var mine_count : int = 0
		for j in get_all_surrounding_cells(i):
			#check if there is a min in the cell
			if is_mine(j):
				mine_count += 1
		#once counted, add the number cell to the tilemap
		if mine_count > 0 :
			set_cell(number_layer, i, tile_id, number_atlas[mine_count - 1])

func generate_grass():
	for y in range(ROWS):
		for x in range(COLS):
			var toggle = ((x + y) % 2)
			set_cell(grass_layer, Vector2i(x, y), tile_id, Vector2i(3 - toggle, 0))

func get_empty_cells():
	var empty_cells := []
	#iterate over grid
	for y in range(ROWS):
		for x in range(COLS):
			#check if the cell is empty and add it to the array
			if not is_mine(Vector2i(x, y)):
				empty_cells.append(Vector2i(x, y))
	return empty_cells

func get_all_surrounding_cells(middle_cell):
	var surrounding_cells := []
	var target_cell
	for y in range(3):
		for x in range(3):
			target_cell = middle_cell + Vector2i(x - 1, y - 1)
			#skip cell if it is the one in the middle
			if target_cell != middle_cell:
				#check that the cell is on the grid
				if (target_cell.x >= 0 and target_cell.x <= COLS - 1
					and target_cell.y >= 0 and target_cell.y <= ROWS - 1):
						surrounding_cells.append(target_cell)
	return surrounding_cells

func _input(event):
	if event is InputEventMouseButton:
		#check if mouse is on the game board
		if event.position.y < ROWS * CELL_SIZE:
			var map_pos := local_to_map(event.position)
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				#check that there is no flag there
				if not is_flag(map_pos):
					#check if it is a mine
					if is_mine(map_pos):
						#check if it is the first click
						if get_parent().first_click:
							move_mine(map_pos)
							generate_numbers()
							process_left_click(map_pos)
						#otherwise end the game
						else:
							end_game.emit()
							show_mines()
					else:
						process_left_click(map_pos)
			#right click places and removes flags
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				process_right_click(map_pos)

func process_left_click(pos):
	#no longer first click
	get_parent().first_click = false
	var revealed_cells := []
	var cells_to_reveal := [pos]
	while not cells_to_reveal.is_empty():
		#clear cell and mark it cleared
		erase_cell(grass_layer, cells_to_reveal[0])
		revealed_cells.append(cells_to_reveal[0])
		#if the cell had a flag then clear it
		if is_flag(cells_to_reveal[0]):
			erase_cell(flag_layer, cells_to_reveal[0])
			flag_removed.emit()
		if not is_number(cells_to_reveal[0]):
			cells_to_reveal = reveal_surrounding_cells(cells_to_reveal, revealed_cells)
		#remove processed cell from array
		cells_to_reveal.erase(cells_to_reveal[0])
	#once click is processed, check if all number tiles are cleared
	var all_cleared := true
	for cell in get_used_cells(number_layer):
		if is_grass(cell):
			all_cleared = false
	if all_cleared:
		game_won.emit()

func process_right_click(pos):
	#check if it is a grass cell
	if is_grass(pos):
		if is_flag(pos):
			erase_cell(flag_layer, pos)
			flag_removed.emit()
		else:
			set_cell(flag_layer, pos, tile_id, flag_atlas)
			flag_placed.emit()

func reveal_surrounding_cells(cells_to_reveal, revealed_cells):
	for i in get_all_surrounding_cells(cells_to_reveal[0]):
		#check that the cell is not already revealed
		if not revealed_cells.has(i):
			if not cells_to_reveal.has(i):
				cells_to_reveal.append(i)
	return cells_to_reveal

func show_mines():
	for mine in mine_coords:
		if is_mine(mine):
			erase_cell(grass_layer, mine)

func move_mine(old_pos):
	for y in range(ROWS):
		for x in range(COLS):
			if not is_mine(Vector2i(x, y)) and get_parent().first_click == true:
				#update array
				mine_coords[mine_coords.find(old_pos)] = Vector2i(x, y)
				#clear the old mine
				erase_cell(mine_layer, old_pos)
				#move to new free space
				set_cell(mine_layer, Vector2i(x, y), tile_id, mine_atlas)
				#no longer first click
				get_parent().first_click = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	highlight_cell()
	#scan mines
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and 
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			var scan_pos := local_to_map(get_local_mouse_position())
			if not is_grass(scan_pos):
				if scanning == false:
					scan_mines(scan_pos)
					scanning = true
	else:
		scanning = false
	
func highlight_cell():
	var mouse_pos := local_to_map(get_local_mouse_position())
	#clear hover tiles and add a fresh one under the mouse
	clear_layer(hover_layer)
	#how over grass cells
	if is_grass(mouse_pos):
		set_cell(hover_layer, mouse_pos, tile_id, hover_atlas)
	else:
		#if the cell is cleared then only hover over number cells
		if is_number(mouse_pos):
			set_cell(hover_layer, mouse_pos, tile_id, hover_atlas)

func scan_mines(pos):
	var unflagged_mines : int = 0
	for i in get_all_surrounding_cells(pos):
		#check if there are any un-mined flags
		if is_flag(i) and not is_mine(i):
			end_game.emit()
			show_mines()
		#check if there are un-flagged mines
		if is_mine(i) and not is_flag(i):
			unflagged_mines += 1
	if unflagged_mines == 0:
		for cell in reveal_surrounding_cells([pos], []):
			if not is_mine(cell):
				process_left_click(cell)

#helper functions
func is_mine(pos):
	return get_cell_source_id(mine_layer, pos) != -1

func is_grass(pos):
	return get_cell_source_id(grass_layer, pos) != -1

func is_number(pos):
	return get_cell_source_id(number_layer, pos) != -1

func is_flag(pos):
	return get_cell_source_id(flag_layer, pos) != -1
