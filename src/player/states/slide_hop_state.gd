extends AirState
## Slide-Hop: jump out of an *established* slide (not off a normal landing —
## that's the bunny hop's job). A flatter, friction-immune hop that keeps
## all horizontal speed: the second bhop-family tech, gated on slide state
## instead of landing-window timing. Landing re-enters the slide while
## crouch is held, so slide → hop → slide chains flow.


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	player.velocity.y = player.stats.slide_hop_velocity
	player.coyote_timer = 0.0
	player.notify_tech(&"slide_hop")
