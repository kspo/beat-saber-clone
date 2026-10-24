extends Control
## Static vector lighting: no texture downloads or per-frame menu animation.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Soft stage lighting behind the floating panels.
	for i in range(12, 0, -1):
		var radius := float(i) * 23.0
		draw_circle(Vector2(1080, 290), radius, Color(0.02, 0.45, 0.75, 0.012))
		draw_circle(Vector2(100, 280), radius, Color(0.65, 0.05, 0.18, 0.008))
	var ribbon := PackedVector2Array([Vector2(300, 8), Vector2(895, 8), Vector2(878, 70), Vector2(316, 70)])
	draw_colored_polygon(ribbon, Color(0.025, 0.2, 0.31, 0.9))
	draw_line(Vector2(300, 8), Vector2(895, 8), Color("4cdcff"), 2.0, true)
	draw_line(Vector2(316, 70), Vector2(878, 70), Color(0.2, 0.7, 1.0, 0.35), 1.0, true)
	for x in [24.0, 1384.0]:
		var tint := Color("ff506b") if x < 100 else Color("53ddff")
		draw_line(Vector2(x, 16), Vector2(x, 62), Color(tint, 0.12), 10.0, true)
		draw_line(Vector2(x, 16), Vector2(x, 62), tint, 2.0, true)
	# Quiet separators keep the utility controls away from the main selection flow.
	draw_line(Vector2(24, 554), Vector2(1384, 554), Color(0.3, 0.65, 0.9, 0.22), 1.0)
	for x in [316.0, 928.0]:
		draw_line(Vector2(x, 84), Vector2(x + 80, 84), Color("42d4ff"), 2.0)
