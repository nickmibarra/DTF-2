func attempt_place_wall():
    var world_pos = get_global_mouse_position()
    print("\nWall Placement Debug:")
    print("Mouse World Position: ", world_pos)
    
    var grid_pos = grid.world_to_grid(world_pos)
    print("Converted Grid Position: ", grid_pos)
    
    if not grid.is_valid_cell(grid_pos):
        return
    
    if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
        return
    
    if gold < WALL_COST:
        return
    
    if grid.set_cell_type(grid_pos, grid.TILE_TYPE.WALL):
        gold -= WALL_COST
        update_gold_display()
        update_tower_buttons() 