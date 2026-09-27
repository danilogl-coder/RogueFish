extends Boss
## Titanacon, o Devorador: a colossal armoured fish. Its bony plates shrug off
## most damage from the outside; the real fight happens inside it. It inhales
## hard enough to swallow the player, who must wreck its vital organs (heart
## and acid glands) while parasites defend them. Enough damage from the inside
## and it spits the player out, stunned and vulnerable for a moment.

const SPRITE_SCALE := 2.0
const SPIT_RATIO := 0.25      ## share of max HP dealt from inside before it spits you out
const OUTER_ARMOR := 0.12     ## plates: outside hits deal 12%

const OUTER_CHIP := 0.08      ## outside hits can only chip this share of max HP per swallow cycle

var stomach                   # Stomach while the player is inside
var inside_dmg := 0.0
var _outer_floor := INF       ## HP that outside damage cannot go below
var _cooldown := 1.5
var _armor_msg_t := 0.0
var _charge_dir := Vector2.RIGHT
var _suck_t := 0.0
var _summon_t := 10.0
var _head: BossPart
var _tail: BossPart


func _setup() -> void:
	sprite = Art.sprite("creatures/titanacon")
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)
	radius = 58.0
	speed = 80.0
	anim_fps = 4.0
	armor_mult = OUTER_ARMOR
	state = "enter"
	_head = add_part(40.0, contact_damage)
	_tail = add_part(28.0, contact_damage * 0.5)


## Where the mouth opens (world space).
func mouth_pos() -> Vector2:
	return position + Vector2(facing * 138.0, 8.0)


func lost_player() -> bool:
	return false  # nothing hides from a titan that inhales the sea


func give_up() -> void:
	pass


func think(delta: float) -> void:
	var p: Player = game.player
	_place_parts()
	if stomach != null:
		# digesting: drifts heavily, rumbling
		vel *= pow(0.2, delta)
		wander(delta, speed * 0.25)
		if randf() < delta * 0.6:
			game.shake(1.5)
		return
	_cooldown -= delta
	_summon_t -= delta
	match state:
		"enter":
			seek(p.position, speed * 1.4, 200.0, delta)
			if player_dist() < 380.0 or state_t > 4.0:
				_go("cruise")
		"cruise":
			var side := -1.0 if p.position.x < position.x else 1.0
			var want := p.position + Vector2(-side * 260.0, -20.0)
			seek(want, speed, 160.0, delta)
			facing = side
			if enraged and _summon_t <= 0.0:
				_summon_t = 12.0
				summon("parasite", 3)
			if _cooldown <= 0.0 and p.alive:
				_go("inhale")
				_suck_t = 3.4 if enraged else 2.8
				armor_mult = 0.3
				game.hud.toast("O Titanacon está sugando o mar!", Color("ff5c4c"))
				Sfx.play("boss_roar", -4.0)
		"inhale":
			vel *= pow(0.05, delta)
			attack_anim = 0.4
			_suck_t -= delta
			var mouth := mouth_pos()
			var k := clampf(state_t / 2.0, 0.0, 1.0)
			var pull := lerpf(110.0, 300.0 if enraged else 260.0, k)
			var to := mouth - p.position
			if p.alive and to.length() < 640.0:
				p.position += to.normalized() * pull * delta
				if to.length() < 34.0:
					armor_mult = 1.0
					game.swallow_player(self)
					_go("digest")
					return
			# pickups and small fish are dragged along too
			for c in game.creatures_in_radius(mouth, 200.0):
				if not c.is_boss and c.tier <= 1:
					c.position += (mouth - c.position).normalized() * pull * 0.8 * delta
			if _suck_t <= 0.0:
				armor_mult = OUTER_ARMOR
				_charge_dir = (p.position - position).normalized()
				telegraph_line(position, _charge_dir, 460.0, 70.0, 0.8)
				_go("aim")
		"aim":
			vel *= pow(0.02, delta)
			facing = signf(_charge_dir.x) if absf(_charge_dir.x) > 0.1 else facing
			if state_t > 0.8:
				_go("charge")
				attack_anim = 0.9
				Sfx.play("dash")
		"charge":
			vel = _charge_dir * (430.0 if enraged else 380.0)
			if state_t > 0.9:
				_go("recover")
		"recover":
			vel *= pow(0.1, delta)
			if state_t > 1.2:
				_cooldown = 3.0 if enraged else 4.0
				_go("cruise")
		"stunned":
			vel *= pow(0.1, delta)
			if state_t > 2.8:
				armor_mult = OUTER_ARMOR
				_cooldown = 4.0
				_go("cruise")


func _go(s: String) -> void:
	state = s
	state_t = 0.0


## Only the charge hurts on contact; while inhaling it wants you whole.
func hostile_now() -> bool:
	return stomach == null and state in ["charge", "enter"] and super.hostile_now()


func _place_parts() -> void:
	var biting := stomach == null and state == "charge"
	_head.contact_damage = contact_damage if biting else 0.0
	_tail.contact_damage = contact_damage * 0.4 if state in ["cruise", "charge"] else 0.0
	_head.position = position + Vector2(facing * 105.0, 4.0)
	_tail.position = position + Vector2(-facing * 128.0, 0.0)


func take_damage(amount: float, info := {}) -> float:
	var organ: bool = info.get("organ", false)
	if stomach != null and not organ:
		return 0.0
	if not organ:
		# the plates can be chipped, but it only dies from the inside
		if _outer_floor == INF:
			_outer_floor = max_hp * (1.0 - OUTER_CHIP)
		var allowed := hp - _outer_floor
		if allowed <= 0.0:
			_armor_msg_t -= get_physics_process_delta_time()
			if _armor_msg_t <= 0.0:
				_armor_msg_t = 2.5
				game.float_text(position + Vector2(0, -70), "BLINDADO! SEJA ENGOLIDO", Color("b8ae9c"), 10)
			return 0.0
		amount = minf(amount, allowed / maxf(armor_mult * 1.25, 0.01))
	var d := super.take_damage(amount, info)
	if organ and not dead:
		inside_dmg += d
		if stomach != null and inside_dmg >= max_hp * SPIT_RATIO:
			spit()
	return d


## Too much damage inside: coughs the player out and is left stunned.
func spit() -> void:
	inside_dmg = 0.0
	_outer_floor = maxf(1.0, hp - max_hp * OUTER_CHIP)
	game.spit_player(self)
	armor_mult = 0.8
	_go("stunned")
	game.hud.banner("CUSPIDO!", "O Titanacon está atordoado: ataque!", Color("ffbf45"))
	game.shake(8.0)


func stomach_ratio() -> float:
	return clampf(inside_dmg / (max_hp * SPIT_RATIO), 0.0, 1.0)


func on_death() -> void:
	if stomach != null:
		game.spit_player(self, true)
	super.on_death()


func _animate(delta: float) -> void:
	super._animate(delta)
	# it always faces its prey while hunting (movement alone would flip it)
	if state in ["enter", "cruise", "inhale", "aim"] and stomach == null:
		facing = -1.0 if game.player.position.x < position.x else 1.0
	elif state == "charge":
		facing = -1.0 if _charge_dir.x < 0.0 else 1.0
	if state == "inhale":
		# hold the full gape while inhaling
		sprite.frame = _swim_n + 1
	elif state == "stunned":
		sprite.frame = _swim_n + 3
	sprite.flip_h = facing < 0.0
	queue_redraw()


func _draw() -> void:
	super._draw()
	if state != "inhale":
		return
	# water streaks rushing into the mouth
	var m := mouth_pos() - position
	for i in 16:
		var a := i * 0.39 + anim_t * 0.3
		var ph := fmod(anim_t * 1.8 + i * 0.29, 1.0)
		var dist := lerpf(230.0, 30.0, ph)
		var dir := Vector2.from_angle(a)
		var from := m + dir * dist
		var to := m + dir * (dist - 26.0)
		draw_line(from, to, Color(0.7, 0.95, 1.0, 0.25 + 0.45 * ph), 1.0)
