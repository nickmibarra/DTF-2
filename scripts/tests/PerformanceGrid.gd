extends "res://scripts/Grid.gd"

var metrics = null

func setup_metrics(test_metrics: Dictionary):
	metrics = test_metrics

func find_path(start: Vector2, end: Vector2) -> PathResult:
	if metrics != null:
		metrics.path_calculations += 1
		var cache_key = _get_path_cache_key(start, end)
		if path_cache.has(cache_key):
			metrics.cache_hits += 1
		else:
			metrics.cache_misses += 1
	
	# Use parent's implementation to maintain caching
	return super.find_path(start, end)

func get_attackables_in_range(pos: Vector2, range: float) -> Array:
	if metrics != null:
		metrics.spatial_queries += 1
	
	# Use parent's implementation to maintain spatial partitioning
	return super.get_attackables_in_range(pos, range) 
