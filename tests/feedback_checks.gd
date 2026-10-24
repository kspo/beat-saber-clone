extends Node
var checks := 0
var failures := 0
func _ready() -> void:
	call_deferred("run_checks")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
		return
	checks += 1
func run_checks() -> void:
	var keyboard := preload("res://OQ_Toolkit/OQ_UI2D/controls/VirtualKeyboard.tscn").instantiate()
	add_child(keyboard)
	await get_tree().process_frame
	check(keyboard._create_input_event(keyboard._backspace_button, true).keycode == KEY_BACKSPACE, "delete mapping")
	check(keyboard._create_input_event(keyboard._space_button, true).unicode == 32, "space mapping")
	keyboard.set_upper_case(true)
	check(keyboard._all_letter_buttons[0].text == "Q", "shift")
	keyboard._toggle_symbols(true)
	check(keyboard._container_symbols.visible and not keyboard._container_letters.visible, "symbols")
	for button in keyboard.find_children("button_*", "Button", true, false):
		check(button.position.x >= 0 and button.position.y >= 0 and button.position.x + button.size.x <= 576 and button.position.y + button.size.y <= 240, "key bounds: " + button.text)
	var driver := preload("res://game/Points_label_driver.tscn").instantiate()
	add_child(driver)
	for i in range(30):
		driver.show_points(Vector3(0, 1, 2.5), 0, "115" if i % 2 == 0 else "x")
	check(driver.points_label.size() == 24, "bounded feedback pool")
	var popup = driver.points_label[5]
	check(popup.label.text == "×", "miss glyph")
	check(popup.global_position.z <= -1.799, "miss remains in front")
	popup._process(2)
	check(not popup.visible and not popup.is_processing(), "feedback expires")
	popup.show_points(Vector3(0, 1, -2), 0, "82", Color.WHITE)
	check(popup.visible and popup.label.modulate.a == 1.0, "pool reuse resets alpha")
	keyboard.queue_free()
	driver.queue_free()
	await get_tree().process_frame
	print("FEEDBACK AND KEYBOARD CHECKS: ", checks, " passed")
	get_tree().quit(1 if failures else 0)
