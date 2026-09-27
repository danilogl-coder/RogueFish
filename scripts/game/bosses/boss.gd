class_name Boss
extends Creature
## Shared boss logic: phases, summons, enrage, parts cleanup.

var enraged := false
var parts: Array = []
var _entered := false
var _hit_frames: Dictionary = {}


## Area attacks can overlap several parts of a big boss in the same frame;
## only the first hit per damage source per physics frame counts.
func take_damage(amount: float, info := {}) -> float:
	var src: String = str(info.get("source", "")) + str(info.get("hit_id", ""))
	if src != "":
		var f := Engine.get_physics_frames()
		if int(_hit_frames.get(src, -1)) == f:
			return 0.0
		_hit_frames[src] = f
	return super.take_damage(amount, info)


func configure_boss(p_id: String, p_def: Dictionary, diff: Dictionary) -> void:
	super.configure_boss(p_id, p_def, diff)


func boss_name() -> String:
	return tr(def.name)


var giving_up := false
var _leave_t := 0.0


## True while the player hides: bosses lose track and roam instead of attacking.
func lost_player() -> bool:
	return game.player.is_hidden and not giving_up


func search(delta: float) -> void:
	wander(delta, speed * 0.45)
	attack_anim = 0.0


func give_up() -> void:
	if giving_up or dead:
		return
	giving_up = true
	_leave_t = 0.0
	Sfx.play("boss_roar", -6.0)


func hostile_now() -> bool:
	return not giving_up and super.hostile_now()


func _physics_process(delta: float) -> void:
	if giving_up and not dead:
		_leave_t += delta
		var away: Vector2 = (position - game.player.position).normalized()
		position += (away + Vector2(0, -0.3)).normalized() * speed * 2.0 * delta
		modulate.a = clampf(1.0 - _leave_t / 2.5, 0.0, 1.0)
		_animate(delta)
		if _leave_t >= 2.5:
			dead = true
			on_death()
			game.on_boss_gave_up(self)
			queue_free()
		return
	if not dead and not enraged and hp < max_hp * 0.5:
		enraged = true
		on_enrage()
	super._physics_process(delta)


func on_enrage() -> void:
	game.float_text(position + Vector2(0, -60), "FÚRIA!", Color("ff5c4c"), 16)
	Sfx.play("boss_roar", -2.0)
	game.shake(6.0)


func summon(creature_id: String, count: int) -> void:
	for i in count:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(40, 80)
		var c: Creature = game.spawn_creature(creature_id, position + off, {"wave": true, "force": true})
		if c:
			c.xp = maxi(1, c.xp / 2)


func telegraph_line(from: Vector2, dir: Vector2, length: float, width: float, t: float) -> void:
	var tg := Telegraph.new().line(length, width, t)
	tg.position = from
	tg.rotation = dir.angle()
	game.layer_back.add_child(tg)


func telegraph_circle(at: Vector2, r: float, t: float) -> void:
	var tg := Telegraph.new().circle(r, t)
	tg.position = at
	game.layer_back.add_child(tg)


func hurt_player_in(at: Vector2, r: float, dmg: float) -> void:
	var p: Player = game.player
	if p.alive and p.position.distance_to(at) < r + p.radius:
		p.take_damage(dmg * dmg_mult, self)


func add_part(r: float, dmg: float) -> BossPart:
	var bp := BossPart.new()
	bp.game = game
	bp.owner_boss = self
	bp.radius = r
	bp.contact_damage = dmg
	bp.dmg_mult = dmg_mult
	bp.position = position
	game.layer_creatures.add_child(bp)
	game.creatures.append(bp)
	parts.append(bp)
	return bp


func on_death() -> void:
	for bp in parts:
		if is_instance_valid(bp):
			bp.dead = true
			bp.queue_free()
	parts.clear()


func _draw() -> void:
	pass
