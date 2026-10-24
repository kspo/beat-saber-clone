extends Panel
class_name VirtualKeyboard


@onready var _reference_button := $ReferenceButton as Button
@onready var _container_letters := $Container_Letters as Container
@onready var _container_symbols := $Container_Symbols as Container

@export var allow_newline := false

const B_SIZE := 48

var NUMBER_LAYOUT := PackedStringArray(["1","2","3","4","5","6","7","8","9","0"])

var BUTTON_LAYOUT_ENGLISH: Array[PackedStringArray] = [
	PackedStringArray(["q","w","e","r","t","y","u","i","o","p"]),
	PackedStringArray(["a","s","d","f","g","h","j","k","l",":"]),
	PackedStringArray(["@","z","x","c","v","b","n","m","!","."]),
	PackedStringArray(["/"])
]

var BUTTON_LAYOUT_SYMBOLS: Array[PackedStringArray] = [
	PackedStringArray(["!","@","#","$","%","^","&","*","(",")"]),
	PackedStringArray([".",'"',"'",",","-","?",":",";","{","}"]),
	PackedStringArray(["+","_","=","|","/","\\","<",">","[","]"])
]


signal enter_pressed
signal cancel_pressed


var _all_letter_buttons: Array[Button] = []

func _toggle_symbols(show_symbols: bool) -> void:
	_container_letters.visible = not show_symbols
	_container_symbols.visible = show_symbols

func _create_input_event(b: Button, pressed: bool) -> InputEventKey:
	var keycode := KEY_NONE
	var key := b.text
	var unicode := 0

	if (b == _toggle_symbols_button):
		_toggle_symbols(b.button_pressed)
		return
	elif (b == _cancel_button):
		if (!pressed): cancel_pressed.emit()
		return
	elif (b == _shift_button):
		if (pressed): 
			set_upper_case(!b.button_pressed) # button event is created before it is actually toggled
		keycode = KEY_SHIFT
	elif (b == _backspace_button):
		keycode = KEY_BACKSPACE
	elif (b == _enter_button):
		keycode = KEY_ENTER
		if (!pressed): enter_pressed.emit()
		if (!allow_newline): return # no key event for enter in this case
	elif (b == _space_button):
		keycode = KEY_SPACE
		key = " "
		unicode = " ".unicode_at(0)
	else:
		keycode = OS.find_keycode_from_string(b.text)
		unicode = key.unicode_at(0)
	

	#print("  Event for " + key + ": scancode = " + str(scancode));
	
	var ev := InputEventKey.new();
	ev.keycode = keycode
	ev.unicode = unicode
	ev.pressed = pressed

	return ev;


# not sure what causes this yet but it happens that a button press
# triggers twice the down without up
var _last_button_down_hack: Button

func _on_button_down(b: Button) -> void:
	if (b == _last_button_down_hack): return
	_last_button_down_hack = b
	
	var ev := _create_input_event(b, true)
	if (!ev): return
	Input.parse_input_event(ev)


func _on_button_up(b: Button) -> void:
	_last_button_down_hack = null
	
	var ev := _create_input_event(b, false)
	if (!ev): return
	Input.parse_input_event(ev)


func _create_button(parent: Node, text: String, x: float, y: float, w: float = 1.0, h: float = 1.0) -> Button:
	var b := _reference_button.duplicate() as Button
	b.text = text
	
	if (b.text.length() == 1):
		var c := b.text.unicode_at(0)
		if (c >= 97 && c <= 122):
			_all_letter_buttons.append(b)
	
	b.position = Vector2(x, y) * B_SIZE + Vector2(3, 4)
	b.custom_minimum_size = Vector2(w, h) * B_SIZE - Vector2(6, 8)
	b.size = b.custom_minimum_size
	b.add_theme_font_size_override("font_size", 21 if text.length() == 1 else 15)
	b.remove_theme_stylebox_override("hover")
	
	b.name = "button_"+text
	
	@warning_ignore("return_value_discarded")
	b.button_down.connect(_on_button_down.bind(b))
	@warning_ignore("return_value_discarded")
	b.button_up.connect(_on_button_up.bind(b))
	
	parent.add_child(b)
	return b

var _toggle_symbols_button: Button
var _shift_button: Button
var _backspace_button: Button
var _enter_button: Button
var _space_button: Button
var _cancel_button: Button

func _create_keyboard_buttons() -> void:
	_toggle_symbols_button = _create_button(self, "# +=", 2, 4, 1.6)
	_toggle_symbols_button.toggle_mode = true
	_shift_button = _create_button(self, "SHIFT", 0.25, 4, 1.75)
	_shift_button.toggle_mode = true
	_backspace_button = _create_button(self, "SİL", 10.25, 1, 1.5)
	_enter_button = _create_button(self, "TAMAM", 10.25, 2, 1.5, 2)
	_space_button = _create_button(self, "B O Ş L U K", 3.6, 4, 6.65)
	_cancel_button = _create_button(self, "KAPAT", 10.25, 0, 1.5)
	_create_button(self, "/", 10.25, 4, 1.5)
	for i in range(NUMBER_LAYOUT.size()):
		_create_button(self, NUMBER_LAYOUT[i], 0.25 + i, 0)
	for row in range(3):
		for col in range(10):
			_create_button(_container_letters, BUTTON_LAYOUT_ENGLISH[row][col], 0.25 + col, row + 1)
			_create_button(_container_symbols, BUTTON_LAYOUT_SYMBOLS[row][col], 0.25 + col, row + 1)
	var style := preload("res://game/ui/RhythmMenuStyle.gd")
	var enter_style := style.box(Color("15617c"), Color("43d9ef"), 1)
	enter_style.content_margin_left = 4
	enter_style.content_margin_right = 4
	_enter_button.add_theme_stylebox_override("normal", enter_style)
	_enter_button.add_theme_color_override("font_color", Color("e5fcff"))
	_backspace_button.add_theme_color_override("font_color", Color("ffa1b5"))
	_cancel_button.add_theme_color_override("font_color", Color("95abc5"))
	_reference_button.visible = false
	_toggle_symbols(false)

func set_cancelable(cancelable: bool) -> void:
	if _cancel_button != null:
		_cancel_button.visible = cancelable

func enter_button_disabled(disabled: bool) -> void:
	if _enter_button != null:
		_enter_button.disabled = disabled
		
func set_upper_case(upper_case: bool) -> void:
	if (upper_case):
		for b in _all_letter_buttons:
			b.text = b.text.to_upper()
	else:
		for b in _all_letter_buttons:
			b.text = b.text.to_lower()

func _ready() -> void:
	var style := preload("res://game/ui/RhythmMenuStyle.gd")
	theme = style.make_theme()
	var panel := style.box(Color("081322"), Color("29445e"), 1)
	panel.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", panel)
	var normal := style.box(Color("192c43"), Color("304a65"), 1)
	normal.set_corner_radius_all(7)
	var hover := style.box(Color("245d78"), Color("73ecff"), 2)
	hover.set_corner_radius_all(7)
	var pressed := style.box(Color("a6f4ff"), Color("e0fcff"), 2)
	pressed.set_corner_radius_all(7)
	for key_style in [normal, hover, pressed]:
		key_style.content_margin_left = 4
		key_style.content_margin_right = 4
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "Button", normal if state == "normal" else hover if state == "hover" else pressed)
	_create_keyboard_buttons()
	_toggle_symbols(false)
