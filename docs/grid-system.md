# Grid System Documentation

## Overview
The grid system manages the game board layout and handles tile-based placement of towers, walls, and the flag. It automatically scales to fit different screen sizes while maintaining aspect ratio.

## Key Features
- Dynamic scaling for different screen resolutions
- Optimized for ultrawide (21:9) displays
- Automatic centering and margin handling
- A* pathfinding for enemy movement

## Grid Properties
- Base cell size: 64x64 pixels
- Grid dimensions: 32x18 cells (optimized for ultrawide)
- Scales to 95% of viewport width
- Leaves 15% vertical space for UI

## Tile Types
```gdscript
enum TILE_TYPE {
    EMPTY,   # Available for building
    WALL,    # Blocks enemy movement
    TOWER,   # Contains a defensive tower
    PATH,    # Used for pathfinding visualization
    FLAG     # The target to defend
}
```

## Key Methods
- `world_to_grid(world_pos)`: Converts screen coordinates to grid coordinates
- `grid_to_world(grid_pos)`: Converts grid coordinates to screen coordinates
- `set_cell_type(pos, type)`: Places or updates a tile
- `find_path(start, end)`: Calculates path using A* algorithm

## Usage Example
```gdscript
# Convert mouse position to grid coordinates
var grid_pos = grid.world_to_grid(get_global_mouse_position())

# Check if cell is valid and empty
if grid.is_valid_cell(grid_pos) and grid.get_cell_type(grid_pos) == TILE_TYPE.EMPTY:
    # Place a tower
    grid.set_cell_type(grid_pos, TILE_TYPE.TOWER)
``` 