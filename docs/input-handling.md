# Input Handling System

## Wall Placement Flow
1. Input is received in TestMap's `_unhandled_input`
2. `attempt_place_wall()` is called when "place_wall" action is detected
3. Coordinate conversion chain:
   ```
   Viewport Mouse Position
   -> Camera.get_screen_to_canvas() (accounts for zoom/position)
   -> World Position
   -> Grid.world_to_grid() (converts to grid coordinates)
   -> Grid.grid_to_world() (centers wall in cell)
   ```

## Key Components
- TestMap: Single point of input handling
- GameCamera: Handles coordinate space conversion
- Grid: Pure utility node for grid operations

## Best Practices
1. Keep Grid node at origin (0,0) with no transform
2. Handle all input in one place (TestMap)
3. Use camera for viewport->world conversion
4. Convert to grid coordinates last

## Example Flow
```gdscript
# 1. Get viewport mouse position
var viewport_mouse_pos = get_viewport().get_mouse_position()

# 2. Convert to world space via camera
var world_pos = camera.get_screen_to_canvas(viewport_mouse_pos)

# 3. Convert to grid coordinates
var grid_pos = grid.world_to_grid(world_pos)

# 4. Place object at grid cell center
var final_pos = grid.grid_to_world(grid_pos)
``` 