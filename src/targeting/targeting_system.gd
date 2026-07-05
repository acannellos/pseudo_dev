class_name TargetingSystem
extends Node
## OoT-style Z-targeting, as a component beside the state machine (like
## [CombatController]). Press Target to lock the nearest targetable node;
## press again to cycle outward through everything in range (wrapping);
## press with nothing else around to release. The lock also breaks on its
## own past [member break_range] or after line of sight stays blocked for
## [member los_grace] seconds.
##
## Targets are nodes in the "targetable" group. Optional contract:
## `is_targetable() -> bool` (dead/downed things return false) and
## `target_point() -> Vector3` (where the orb hovers and LOS rays aim);
## both have sensible fallbacks.
##
## Consumers listen up: the companion orb, the orbit camera, and
## [Player] facing/flip-variant logic all key off [method is_active].

signal target_acquired(target: Node3D)
signal target_released

@export var player: Player
## Lock-on candidates must be within this range of the player.
@export var acquire_range := 14.0
## An active lock breaks past this distance.
@export var break_range := 18.0
## Lock survives a blocked line of sight for this long (dodging behind a
## pillar for a beat is fine; camping there breaks the lock).
@export var los_grace := 0.5
## Seconds between LOS raycasts — throttled, not per-frame.
@export var los_check_interval := 0.2

var target: Node3D = null

var _los_lost := 0.0
var _los_timer := 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"target"):
		_on_target_pressed()
	if target != null:
		_validate(delta)


func is_active() -> bool:
	return target != null


## Where the lock aims on the current target.
func target_point() -> Vector3:
	return point_of(target)


static func point_of(node: Node3D) -> Vector3:
	if node.has_method(&"target_point"):
		return node.target_point()
	return node.global_position + Vector3.UP


func _on_target_pressed() -> void:
	var candidates := _gather_candidates()
	if target == null:
		if not candidates.is_empty():
			_set_target(candidates[0])
		return
	# Cycle outward through the others; wrap back to the nearest. With no
	# other candidate in range, the press releases the lock instead.
	candidates.erase(target)
	if candidates.is_empty():
		release()
	else:
		var index := 0
		var my_dist := _dist_to(target)
		while index < candidates.size() and _dist_to(candidates[index]) <= my_dist:
			index += 1
		_set_target(candidates[index % candidates.size()])


## Valid, in-range, visible targetables sorted nearest-first.
func _gather_candidates() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"targetable"):
		var body := node as Node3D
		if body == null or not _is_valid(body):
			continue
		if _dist_to(body) > acquire_range or not _has_los(body):
			continue
		found.append(body)
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _dist_to(a) < _dist_to(b))
	return found


func _set_target(node: Node3D) -> void:
	target = node
	_los_lost = 0.0
	_los_timer = 0.0
	target_acquired.emit(node)


func release() -> void:
	if target == null:
		return
	target = null
	target_released.emit()


func _validate(delta: float) -> void:
	if not _is_valid(target) or _dist_to(target) > break_range:
		release()
		return
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = los_check_interval
		if _has_los(target):
			_los_lost = 0.0
		else:
			_los_lost += los_check_interval
			if _los_lost >= los_grace:
				release()


func _is_valid(node: Node3D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	if node.has_method(&"is_targetable"):
		return node.is_targetable()
	return true


func _dist_to(node: Node3D) -> float:
	return player.global_position.distance_to(node.global_position)


## Chest-to-target ray against world geometry (layer 1), ignoring the
## target's own body.
func _has_los(node: Node3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	var from := player.global_position + Vector3.UP
	var exclude: Array[RID] = [player.get_rid()]
	if node is CollisionObject3D:
		exclude.append((node as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(
			from, point_of(node), 1, exclude)
	return space.intersect_ray(query).is_empty()
