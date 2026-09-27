extends Creature
## Piolho-do-mar (Cymothoa-like fish louse). Swims in erratic darts looking for
## a host. Touching the player (outside a dash) means it slips in through the
## gills and joins the colony living inside them. Males are drawn to hosts in
## general; the female smells males from afar (pheromones) and comes to mate.

var female := false
var _zig := 0.0
var _rest := 0.0


func _setup() -> void:
	female = id == "louse_f"
	anim_fps = 10.0
	_zig = randf() * TAU


func _sense() -> float:
	var p: Player = game.player
	if female and p.infest and p.infest.males() > 0:
		return 340.0   # pheromones: males inside the host call the female
	return 150.0


func think(delta: float) -> void:
	var p: Player = game.player
	_rest -= delta
	var can_host: bool = p.alive and not p.swallowed and p.infest != null and not p.infest.full()
	if can_host and _rest <= 0.0 and player_visible(_sense()):
		# darting zig-zag approach, hard to bite
		_zig += delta * 7.0
		var to := (p.position - position).normalized()
		var side := Vector2(-to.y, to.x) * sin(_zig) * 0.7
		seek(p.position + side * 30.0, speed * (1.25 if female else 1.1), 520.0, delta)
		var lim := radius + p.radius
		if position.distance_squared_to(p.position) <= lim * lim:
			_try_enter(p)
		return
	var threat := find_threat(90.0)
	if threat != Vector2.INF:
		flee(threat, speed, 400.0, delta)
		return
	wander(delta, speed * 0.4)


func _try_enter(p: Player) -> void:
	if p._invuln > 0.0 and p._dash_t > -0.2:
		# dashed through it: shaken off
		_rest = 1.2
		vel = (position - p.position).normalized() * speed * 2.0
		return
	p.infest.add("f" if female else "m", position, "")
	dead = true
	queue_free()
