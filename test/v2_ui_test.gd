extends Node

# V2.0 public-release UI regression and runtime evidence.
# Run:
#   godot --path . res://test/v2_ui_test.tscn

const SLOT_PATH := "user://save_slot_2.json"
const SETTINGS_PATH := "user://settings.json"
const LOGICAL_BOUNDS := Rect2(0, 0, 1280, 720)

var main_node: Control
var _backups: Dictionary = {}
var _original_slot := 0
var _failures: Array[String] = []
var _assertions := 0

func _ready() -> void:
	_snapshot_user_file(SLOT_PATH)
	_snapshot_user_file(SETTINGS_PATH)
	_original_slot = GameState.save_slot
	GameState.save_slot = 2

	await get_tree().process_frame
	main_node = load("res://scenes/main.tscn").instantiate()
	add_child(main_node)
	await _settle()
	await _run()

func _snapshot_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		_backups[path] = {
			"exists": true,
			"bytes": FileAccess.get_file_as_bytes(path),
		}
	else:
		_backups[path] = { "exists": false, "bytes": PackedByteArray() }

func _restore_user_files() -> void:
	for path in _backups:
		var entry: Dictionary = _backups[path]
		if entry.exists:
			var file = FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_buffer(entry.bytes)
				file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	GameState.save_slot = _original_slot

func _write_test_save() -> void:
	var file = FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"region": 0,
			"cycle": 0,
			"gold": 123,
			"hero_name": "UI回归",
			"run_stats": { "kills": 0 },
		}))
		file.close()

func _remove_test_save() -> void:
	if FileAccess.file_exists(SLOT_PATH):
		DirAccess.remove_absolute(SLOT_PATH)

func _settle(frames: int = 5) -> void:
	for _i in range(frames):
		await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("[PASS] ", message)
	else:
		_failures.append(message)
		push_error("[FAIL] " + message)

func _visible_title_buttons() -> Array[Button]:
	var out: Array[Button] = []
	var group = main_node.title_view.find_child("TitleButtonGroup", true, false)
	if group:
		for child in group.get_children():
			if child is Button and child.visible:
				out.append(child)
	return out

func _assert_title_layout(expected_count: int, label: String) -> void:
	var buttons = _visible_title_buttons()
	_expect(buttons.size() == expected_count, "%s has %d visible title buttons" % [label, expected_count])
	for button in buttons:
		var rect = button.get_global_rect()
		_expect(LOGICAL_BOUNDS.encloses(rect), "%s keeps %s fully inside 1280x720" % [label, button.name])
	var exit_button = main_node.title_view.find_child("ExitButton", true, false) as Button
	_expect(exit_button != null and exit_button.visible, "%s shows the Exit button" % label)
	if exit_button:
		_expect(exit_button.get_global_rect().end.y <= 720.0, "%s keeps Exit bottom at or above y=720" % label)

func _set_window_size(target: Vector2i) -> void:
	get_window().size = target
	await _settle(8)
	_expect(get_window().size == target, "physical window size is %dx%d" % [target.x, target.y])

func _shot(name_: String, expected_size: Vector2i = Vector2i.ZERO) -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var directory = ProjectSettings.globalize_path("res://test/shots_v2_ui")
	DirAccess.make_dir_recursive_absolute(directory)
	var result = image.save_png(directory.path_join(name_ + ".png"))
	_expect(result == OK, "saved runtime screenshot %s" % name_)
	print("[shot] %s (%dx%d)" % [name_, image.get_width(), image.get_height()])
	if expected_size != Vector2i.ZERO:
		_expect(
			image.get_width() == expected_size.x and image.get_height() == expected_size.y,
			"%s has physical capture size %dx%d" % [name_, expected_size.x, expected_size.y]
		)

func _find_text(root: Node, exact_text: String) -> bool:
	if root is Label and root.text == exact_text:
		return true
	for child in root.get_children():
		if _find_text(child, exact_text):
			return true
	return false

func _assert_help_layout(modal: ModalLayer, label: String) -> Dictionary:
	var root = modal._panel.find_child("HelpModalRoot", true, false) as VBoxContainer
	var title = modal._panel.find_child("HelpTitle", true, false) as Label
	var scroll = modal._panel.find_child("HelpScrollContainer", true, false) as ScrollContainer
	var content = modal._panel.find_child("HelpContentVBox", true, false) as VBoxContainer
	var close_button = modal._panel.find_child("HelpCloseButton", true, false) as Button
	_expect(root != null, "%s has a dedicated Help root" % label)
	_expect(title != null, "%s has a fixed title" % label)
	_expect(scroll != null, "%s has a ScrollContainer" % label)
	_expect(content != null, "%s has a dedicated scroll content VBox" % label)
	_expect(close_button != null, "%s has a fixed close button" % label)
	_expect(LOGICAL_BOUNDS.encloses(modal._panel.get_global_rect()), "%s panel stays inside 1280x720" % label)
	if scroll and close_button:
		_expect(not scroll.is_ancestor_of(close_button), "%s close button is outside the scroll content" % label)
		_expect(LOGICAL_BOUNDS.encloses(close_button.get_global_rect()), "%s close button is visible inside the window" % label)
		var bar = scroll.get_v_scroll_bar()
		_expect(bar.max_value > bar.page, "%s content is vertically scrollable" % label)
	return {
		"root": root,
		"scroll": scroll,
		"close": close_button,
	}

func _run() -> void:
	var title = main_node.title_view
	var modal = main_node.modal_layer

	_write_test_save()
	title.refresh()
	await _set_window_size(Vector2i(1280, 720))
	_assert_title_layout(6, "saved 1280x720")
	_expect(_find_text(title, "v5.0 · 远征路线版"), "in-game version label remains v5.0 · 远征路线版")
	await _shot("title_with_save_1280x720", Vector2i(1280, 720))

	_remove_test_save()
	title.refresh()
	await _settle()
	_assert_title_layout(5, "empty 1280x720")
	await _shot("title_without_save_1280x720", Vector2i(1280, 720))

	_write_test_save()
	title.refresh()
	await _set_window_size(Vector2i(1366, 768))
	_assert_title_layout(6, "saved 1366x768")
	await _shot("title_1366x768", Vector2i(1280, 720))

	await _set_window_size(Vector2i(1600, 900))
	_assert_title_layout(6, "saved 1600x900")
	await _shot("title_1600x900", Vector2i(1280, 720))

	await _set_window_size(Vector2i(1920, 1080))
	_assert_title_layout(6, "saved 1920x1080")
	await _shot("title_1920x1080", Vector2i(1280, 720))

	await _set_window_size(Vector2i(1280, 720))
	var help_button = title.find_child("HelpButton", true, false) as Button
	_expect(help_button != null, "title Help button is available")
	if help_button:
		help_button.pressed.emit()
	await _settle(12)
	var help_nodes = _assert_help_layout(modal, "title Help")
	var scroll = help_nodes.scroll as ScrollContainer
	var close_button = help_nodes.close as Button
	if scroll:
		scroll.scroll_vertical = 0
		await _settle()
		await _shot("help_top", Vector2i(1280, 720))
		await _shot("help_1280x720", Vector2i(1280, 720))

		var bar = scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int((bar.max_value - bar.page) / 2.0)
		await _settle()
		_expect(close_button != null and LOGICAL_BOUNDS.encloses(close_button.get_global_rect()), "Help close remains visible at middle scroll")
		await _shot("help_middle", Vector2i(1280, 720))

		var page_down = InputEventKey.new()
		page_down.keycode = KEY_PAGEDOWN
		page_down.pressed = true
		modal._on_help_scroll_gui_input(page_down, scroll)
		_expect(scroll.scroll_vertical > 0, "PageDown changes Help scroll position")
		scroll.scroll_vertical = int(bar.max_value)
		await _settle()
		_expect(close_button != null and LOGICAL_BOUNDS.encloses(close_button.get_global_rect()), "Help close remains visible at bottom scroll")
		await _shot("help_bottom_close_visible", Vector2i(1280, 720))

	modal.try_escape()
	await _settle()
	_expect(not modal.is_open(), "Esc closes Help from title")

	modal.open("region_select", { "in_run": false })
	await _settle()
	modal.open("help", {})
	await _settle(12)
	_expect(modal._stack.size() == 1, "Help overlays an existing modal on the stack")
	await _shot("help_overlay_stack_return", Vector2i(1280, 720))
	modal.try_escape()
	await _settle()
	_expect(modal.is_open() and modal._current_type == "region_select", "Esc returns to the underlying stacked modal")
	modal.try_escape()
	await _settle()
	_expect(not modal.is_open(), "second Esc closes the restored modal")

	main_node._current_view = "map"
	title.visible = false
	main_node.map_view.visible = true
	main_node.hud.visible = true
	modal.open("help", {})
	await _settle(12)
	_assert_help_layout(modal, "map-context Help")
	modal.try_escape()
	await _settle()
	_expect(not modal.is_open(), "Esc closes Help from map context")

	_restore_user_files()
	if _failures.is_empty():
		print("V2_UI_TEST: PASS (%d assertions)" % _assertions)
		get_tree().quit(0)
	else:
		print("V2_UI_TEST: FAIL (%d/%d failed)" % [_failures.size(), _assertions])
		for failure in _failures:
			print("  - ", failure)
		get_tree().quit(1)

func _exit_tree() -> void:
	_restore_user_files()
