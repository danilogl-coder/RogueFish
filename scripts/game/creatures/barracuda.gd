extends Creature
## Barracuda: stalks at a distance, telegraphs, then dashes in a straight line.

var _dash_dir := Vector2.RIGHT
var _stalk_len := 2.0
var _tele: Telegraph


func _setup() -> void:
	anim_fps = 9.0
	state = "roam"


func think(delta: float) -> void:
	var p: Player = game.player
	match state:
		"roam":
			if fears_player() and player_dist() < 140.0:
				flee(p.position, speed * 1.3, 200.0, delta)
				return
			wander(delta, speed * 0.6)
			if is_wave or player_visible(230.0):
				_go("stalk")
				_stalk_len = randf_range(1.2, 2.4)
			else:
				var prey := find_prey(180.0)
				if prey and randf() < delta:
					_dash_dir = (prey.position - position).normalized()
					_go("aim")
		"stalk":
			var away := (position - p.position)
			if away.length() < 1.0:
				away = Vector2.RIGHT
			var want := p.position + away.normalized() * 140.0
			want.y = lerpf(want.y, p.position.y, 0.7)
			seek(want, speed, 200.0, delta)
			facing = signf(p.position.x - position.x)
			if state_t > _stalk_len:
				_dash_dir = (p.position - position).normalized()
				_go("aim")
			elif not is_wave and not player_visible(300.0):
				_go("roam")
		"aim":
			vel *= pow(0.02, delta)
			facing = signf(_dash_dir.x) if absf(_dash_dir.x) > 0.05 else facing
			flash_t = 0.03 if int(state_t * 12.0) % 2 == 0 else 0.0
			if _tele == null:
				_tele = Telegraph.new().line(210.0, 10.0, 0.5)
				_tele.position = position
				_tele.rotation = _dash_dir.angle()
				game.layer_back.add_child(_tele)
			if state_t > 0.5:
				_go("dash")
				vel = _dash_dir * 400.0
				attack_anim = 0.5
				Sfx.play("dash", -6.0)
		"dash":
			vel = _dash_dir * 400.0
			for prey2 in game.grid.query(position, radius):
				if prey2 != self and prey2.faction == "herb" and prey2.tier < tier and not prey2.dead:
					prey2.die({"eaten": true})
			if state_t > 0.55:
				_go("recover")
		"recover":
			vel *= pow(0.05, delta)
			if state_t > 0.9:
				_go("stalk" if (is_wave or player_visible(260.0)) else "roam")


func _go(s: String) -> void:
	state = s
	state_t = 0.0
	if s != "aim":
		_tele = null


func _animate(delta: float) -> void:
	super._animate(delta)
	if state == "dash" or state == "aim":
		sprite.flip_h = _dash_dir.x < 0.0
