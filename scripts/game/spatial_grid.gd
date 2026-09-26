class_name SpatialGrid
extends RefCounted
## Uniform hash grid rebuilt every physics frame for fast radius queries.

const CELL := 48.0

var cells: Dictionary = {}


func clear() -> void:
	cells.clear()


func insert(obj: Node2D) -> void:
	var k := Vector2i(floori(obj.position.x / CELL), floori(obj.position.y / CELL))
	var arr = cells.get(k)
	if arr == null:
		cells[k] = [obj]
	else:
		arr.append(obj)


## Objects whose body (obj.radius) overlaps the circle.
func query(pos: Vector2, r: float, max_body := 40.0) -> Array:
	var out := []
	var rr := r + max_body
	var x0 := floori((pos.x - rr) / CELL)
	var x1 := floori((pos.x + rr) / CELL)
	var y0 := floori((pos.y - rr) / CELL)
	var y1 := floori((pos.y + rr) / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var arr = cells.get(Vector2i(cx, cy))
			if arr == null:
				continue
			for o in arr:
				if not is_instance_valid(o):
					continue
				var lim: float = r + o.radius
				if o.position.distance_squared_to(pos) <= lim * lim:
					out.append(o)
	return out
