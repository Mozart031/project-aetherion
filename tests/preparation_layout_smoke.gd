extends SceneTree

const Layout = preload("res://scripts/preparation_board_layout.gd")
var failures := 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for viewport in [Vector2(320, 640), Vector2(360, 800), Vector2(480, 900), Vector2(720, 1280), Vector2(900, 480)]:
		for observer in [0, 1]:
			var layout := Layout.new()
			layout.viewport_size = viewport
			layout.observer = observer
			var own_rect := layout.half_rect(true)
			var own_centers := {}
			for x in range(8):
				for y in range(4):
					var cell := Vector2i(x, y)
					if layout.is_own(cell):
						own_centers[cell] = layout.center(cell)
			_check(own_centers.size() == 16, "Exactly sixteen logical sections belong to either observer")
			for tick_time in [-1.0, 600.0, 601.5, 606.0, 612.0, 900.0]:
				layout.joined_tick = -1 if tick_time < 0 else 600
				layout.tick_time = maxf(0, tick_time)
				_check(layout.half_rect(true) == own_rect, "Own territory never moves during preparation or join")
				var rival := layout.half_rect(false)
				_check(rival.end.y <= own_rect.position.y and rival.position.y >= 100, "Rival stays above the local territory without overlap")
				_check(own_rect.end.y < viewport.y - 178 and own_rect.position.x >= 12 and own_rect.end.x <= viewport.x - 12, "All sections fit above the compact card dock")
				var seen := {}
				for x in range(8):
					for y in range(4):
						var cell := Vector2i(x, y)
						var center := layout.center(cell)
						_check(layout.cell_at(center) == cell and not seen.has(center), "Thirty-two centers have unique reversible hit tests at every animation fraction")
						seen[center] = true
						if layout.is_own(cell):
							_check(center == own_centers[cell], "Every own section keeps its spatial reference")
				_check(layout.cell_at(Vector2(-1, -1)) == Vector2i(-1, -1), "Outside touches never map into the board")
				if layout.progress() < 1:
					_check(layout.cell_at(Vector2(rival.get_center().x, (rival.end.y + own_rect.position.y) * 0.5)) == Vector2i(-1, -1), "The gap between separated boards is not a legal cell")
			layout.joined_tick = 600
			layout.tick_time = 606
			_check(is_equal_approx(layout.progress(), 0.5), "Six ticks are half of the provisional 0.6 second transition")
			layout.tick_time = 612
			_check(layout.progress() == 1.0 and is_equal_approx(layout.half_rect(false).end.y, own_rect.position.y), "Twelve ticks complete a single contiguous 4x8 board")
	if failures == 0:
		print("PASS: 32-section layout, fixed local lower half, sealed upper half, reversible moving coordinates, both observers and portrait sizes")
	quit(0 if failures == 0 else 1)
