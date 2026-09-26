class_name BossPart
extends Creature
## Extra hurtbox for multi-part bosses. Forwards damage to its owner and hurts
## the player on contact. Position is driven by the owner.

var owner_boss: Creature
var damage_share := 0.8


func _init() -> void:
	faction = "boss"
	is_boss = true
	swallowable = false
	tier = 9


func _physics_process(delta: float) -> void:
	if dead:
		return
	_contact_cd -= delta
	if owner_boss == null or not is_instance_valid(owner_boss) or owner_boss.dead:
		dead = true
		queue_free()
		return
	_contact(delta)


func take_damage(amount: float, info := {}) -> float:
	if owner_boss == null or owner_boss.dead:
		return 0.0
	return owner_boss.take_damage(amount * damage_share, info)


func hostile_now() -> bool:
	return contact_damage > 0.0


func _draw() -> void:
	pass
