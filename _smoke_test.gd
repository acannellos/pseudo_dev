extends SceneTree
## Throwaway headless smoke test: lunge gating, double-press cancel, focus
## mode, sidearm, damage numbers, breakables.

var _frames := 0
var _saw_damage_number := false
var _arrow_target: Node
var _arrow_target_hp := 0
var _barrel: Node
var _failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var player := current_scene.find_child("Player", true, false) as Player
	if player == null:
		return false
	var targeting := player.targeting
	var combat := current_scene.find_child("CombatController", true, false) as CombatController
	match _frames:
		10:
			player.global_position = Vector3(0, 0.3, 0.7)
			player.velocity = Vector3.ZERO
			Input.action_press(&"target")
		13:
			Input.action_release(&"target")
			_check(targeting.is_active(), "lock acquired")
		20:
			# Attack with NO forward input: must be a normal swing, not a lunge.
			Input.action_press(&"attack")
		24:
			Input.action_release(&"attack")
			_check(player.state_machine.current_state.name != &"Lunge",
					"neutral targeted attack stayed a swing")
			_check(combat.combo_index == 1, "neutral attack ran combo swing 1")
		80:
			Input.action_press(&"move_forward")
		110:
			Input.action_press(&"attack")
		114:
			Input.action_release(&"attack")
			Input.action_release(&"move_forward")
			_check(player.state_machine.current_state.name == &"Lunge",
					"forward+attack lunged (state %s)"
					% player.state_machine.current_state.name)
		150:
			_check(player.sidearm.ammo == 20, "sidearm starts full")
			if not targeting.is_active():
				# The lunge may have downed the first dummy; re-lock another.
				Input.action_press(&"target")
		153:
			Input.action_release(&"target")
			_check(targeting.is_active(), "have a lock for the arrow shot")
			_arrow_target = targeting.target
			_arrow_target_hp = _arrow_target.get("_hp")
			Input.action_press(&"sidearm")
		156:
			Input.action_release(&"sidearm")
			_check(player.sidearm.ammo == 19, "sidearm spent ammo")
		200:
			_check(is_instance_valid(_arrow_target)
					and int(_arrow_target.get("_hp")) < _arrow_target_hp,
					"arrow damaged its target")
			_check(_saw_damage_number, "damage number appeared")
		206:
			if not targeting.is_active():
				Input.action_press(&"target")
		208:
			Input.action_release(&"target")
		212:
			_check(targeting.is_active(), "locked before double press")
		244:
			# > 0.3 s since any earlier press: this one is a plain cycle…
			Input.action_press(&"target")
		246:
			Input.action_release(&"target")
		248:
			# …and this quick second press is the double-press cancel.
			Input.action_press(&"target")
		250:
			Input.action_release(&"target")
		254:
			_check(not targeting.is_active(), "double press cancelled lock")
		258:
			# Focus mode: hold target somewhere with nothing in range.
			player.global_position = Vector3(30, 0.3, -26)
			player.velocity = Vector3.ZERO
		282:
			Input.action_press(&"target")
		290:
			_check(targeting.is_focusing(), "focus mode began")
			_check(player.is_targeting(), "focus counts as engaged")
			_check(not targeting.is_active(), "focus is not a lock")
		294:
			Input.action_release(&"target")
		298:
			_check(not targeting.is_focusing(), "focus ended on release")
			_barrel = current_scene.find_child("Barrel1", true, false)
			_check(_barrel != null, "barrel exists")
			_barrel.take_hit({"damage": 1, "position": player.global_position})
		304:
			_check(not is_instance_valid(_barrel), "barrel broke")
			var orb: ManaOrb = null
			for child in current_scene.get_children():
				if child is ManaOrb:
					orb = child
			_check(orb != null, "mana orb dropped")
			if orb != null:
				player.global_position = orb.global_position
				player.velocity = Vector3.ZERO
		314:
			_check(player.sidearm.ammo == 20, "mana orb refilled ammo (%d)"
					% player.sidearm.ammo)
		318:
			if _failures == 0:
				print("SMOKE TEST PASSED")
			else:
				print("SMOKE TEST FAILED: %d failures" % _failures)
			return true
	if _frames > 156 and _frames < 200:
		for child in current_scene.get_children():
			if child is DamageNumber:
				_saw_damage_number = true
	return false
