extends Creature
## Orca, the mega predator: roams open water, hunts anything below it in the
## food chain (sharks included) and the player. Circles, then rams. Hide in a
## cave or kelp thicket to escape it... or bring it down for a legendary prize.

var _target: Node2D
var _orbit_a := 0.0
var _charge_dir := Vector2.RIGHT
var _warn_cd := 0.0


func _setup() -> void:
	anim_fps = 5.0
	swallowable = false
	state = "patrol"
	radius = 22.0


func think(delta: float) -> void:
	_warn_cd -= delta
	var p: Player = game.player
	if player_visible(620.0) and _warn_cd <= 0.0:
		_warn_cd = 25.0
		game.hud.toast("MEGAPREDADOR POR PERTO!", Color("ff5c4c"))
		Sfx.play("warning")
	match state:
		"patrol":
			if HerbUtil.scavenge(self, delta, 200.0):
				return
			wander(delta, speed * 0.6)
			if player_visible(240.0) or (provoked and player_visible(420.0)):
				_target = p
			elif hungry():
				_target = find_prey(420.0)
			if _target:
				_orbit_a = (position - _target.position).angle()
				_go("circle")
		"circle":
			if not _valid_target():
				_go("patrol")
				return
			_orbit_a += delta * 1.25
			var want: Vector2 = _target.position + Vector2.from_angle(_orbit_a) * Vector2(150, 90)
			seek(want, speed * 1.5, 320.0, delta)
			if state_t > 2.2:
				_charge_dir = (_target.position - position).normalized()
				if _target == p:
					var tg := Telegraph.new().line(360.0, 30.0, 0.55)
					tg.position = position
					tg.rotation = _charge_dir.angle()
					game.layer_back.add_child(tg)
				_go("aim")
		"aim":
			vel *= pow(0.05, delta)
			facing = signf(_charge_dir.x)
			if state_t > 0.55:
				_go("charge")
				attack_anim = 0.8
				Sfx.play("dash")
		"charge":
			vel = _charge_dir * 340.0
			for c in game.grid.query(position + _charge_dir * radius, radius):
				if can_eat(c):
					eat_prey(c)
			if state_t > 0.8:
				_go("recover")
		"recover":
			vel *= pow(0.2, delta)
			if state_t > 1.1:
				_go("circle" if _valid_target() else "patrol")


func _valid_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _target is Creature:
		return not _target.dead
	return player_visible(460.0)


func _go(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "patrol":
		_target = null


func _animate(delta: float) -> void:
	super._animate(delta)
	if state == "aim" or state == "charge":
		sprite.flip_h = _charge_dir.x < 0.0


func on_hurt(_info: Dictionary) -> void:
	provoked = true


func on_death() -> void:
	Profile.bump("orcas")
	game.hud.banner("ORCA ABATIDA!", "O megapredador caiu", Color("ffbf45"))
	game.world.spawn_boss_chest(position)
	game.shake(8.0)
