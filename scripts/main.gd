extends Node2D

var sim := AetherionSimulation.new()
var accumulator := 0.0
var auto_attack := true

func _ready() -> void:
	sim.queue_summon(0, "boar", Vector2i(3, 1))
	sim.queue_summon(1, "turtle", Vector2i(4, 1))
	queue_redraw()

func _process(delta: float) -> void:
	accumulator += minf(delta, 0.25)
	while accumulator >= AetherionSimulation.TICK_SECONDS:
		# Demo-only command producer: combat is resolved by the simulation.
		if auto_attack and sim.units.size() == 2:
			sim.queue_attack(int(sim.units[0]["id"]), int(sim.units[1]["id"]))
			sim.queue_attack(int(sim.units[1]["id"]), int(sim.units[0]["id"]))
		sim.step()
		accumulator -= AetherionSimulation.TICK_SECONDS
	queue_redraw()

func _draw() -> void:
	var cell_size := 64.0
	var origin := Vector2(45, 90)
	for y in range(AetherionSimulation.HEIGHT):
		for x in range(AetherionSimulation.WIDTH):
			var rect := Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * (cell_size - 2.0))
			draw_rect(rect, Color(0.16, 0.30, 0.24) if x < 4 else Color(0.30, 0.20, 0.30))
	for unit in sim.units:
		var cell: Vector2i = unit["cell"]
		var pos := origin + Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5
		draw_circle(pos, 19.0, Color(0.30, 0.78, 0.95) if int(unit["owner"]) == 0 else Color(1.0, 0.55, 0.28))
		draw_circle(pos, 5.0, Color.BLACK)
