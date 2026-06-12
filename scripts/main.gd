extends Control

# ============================================================
# 主控制器
# 场景树(程序化构建):
#   ShakeRoot
#     Background(TextureRect) / Weather / ViewLayer(Title|Map|Combat)
#   HUD / ModalLayer / ToastLayer
# ============================================================

const TitleViewScript = preload("res://scripts/ui/title_view.gd")
const MapViewScript = preload("res://scripts/ui/map_view.gd")
const CombatViewScript = preload("res://scripts/ui/combat_view.gd")
const HudPanelScript = preload("res://scripts/ui/hud_panel.gd")
const ModalLayerScript = preload("res://scripts/ui/modal_layer.gd")
const WeatherScript = preload("res://scripts/fx/weather.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const CGLayerScript = preload("res://scripts/ui/cg_layer.gd")

var shake_root: Control
var background: TextureRect
var weather: WeatherFX
var title_view: TitleView
var map_view: MapView
var combat_view: CombatView
var hud: HudPanel
var modal_layer: ModalLayer
var toast_layer: VBoxContainer
var cg_layer: CGLayer

var combat_node: CombatStateMachine = null
var _shake_amount: float = 0.0
var _current_view: String = ""

const BG_NAMES := ["forest", "desert", "snow", "volcano", "ruins"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().theme = UITheme.build_theme()

	_build_tree()
	_connect_signals()
	_set_region_visuals(0)
	_show_view("title")

func _build_tree() -> void:
	shake_root = Control.new()
	shake_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shake_root)

	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shake_root.add_child(background)

	weather = WeatherScript.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shake_root.add_child(weather)

	var view_layer = Control.new()
	view_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shake_root.add_child(view_layer)

	title_view = TitleViewScript.new()
	view_layer.add_child(title_view)
	map_view = MapViewScript.new()
	view_layer.add_child(map_view)
	combat_view = CombatViewScript.new()
	view_layer.add_child(combat_view)

	hud = HudPanelScript.new()
	add_child(hud)

	modal_layer = ModalLayerScript.new()
	add_child(modal_layer)

	toast_layer = VBoxContainer.new()
	toast_layer.position = Vector2(440, 88)
	toast_layer.size = Vector2(400, 200)
	toast_layer.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_layer.add_theme_constant_override("separation", 6)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)

	# 剧情 CG 层（最顶层，播放时屏蔽其它输入）
	cg_layer = CGLayerScript.new()
	add_child(cg_layer)

func _connect_signals() -> void:
	SignalBus.view_changed.connect(_show_view)
	SignalBus.show_toast.connect(_show_toast)
	SignalBus.shake_screen.connect(_on_shake)
	SignalBus.region_changed.connect(_set_region_visuals)
	SignalBus.combat_started.connect(_on_combat_started)
	SignalBus.combat_ended.connect(_on_combat_ended)
	SignalBus.map_generated.connect(_on_map_generated)
	SignalBus.play_cg.connect(func(ids, tag): cg_layer.play(ids, tag))

func _on_map_generated() -> void:
	if _current_view == "map":
		map_view.refresh()

# ------------------------------------------------------------
# 视图切换
# ------------------------------------------------------------
func _show_view(view_name: String) -> void:
	_current_view = view_name
	title_view.visible = view_name == "title"
	map_view.visible = view_name == "map"
	combat_view.visible = view_name == "combat"
	hud.visible = view_name != "title"

	match view_name:
		"title":
			GameState.change_state(GameState.State.TITLE)
			_set_region_visuals(0)
			title_view.refresh()
			_free_combat_node()
		"map":
			map_view.refresh()
			hud.refresh_all()
			_free_combat_node()
		"combat":
			hud.refresh_all()

# ------------------------------------------------------------
# 战斗节点生命周期
# ------------------------------------------------------------
func _on_combat_started(_enemies: Array) -> void:
	# Boss 召唤会重发此信号：若状态机仍持有同一份战斗数据，仅刷新视图
	if combat_node != null and is_instance_valid(combat_node) and combat_node.combat_data == GameState.combat_state:
		combat_view.rebuild_enemies(GameState.combat_state.enemies)
		combat_view.combat_node = combat_node
		return
	_free_combat_node()
	combat_view.clear_log()
	combat_node = CombatStateScript.new()
	add_child(combat_node)
	combat_view.combat_node = combat_node
	combat_node.start_combat(GameState.combat_state)

func _on_combat_ended(_victory: bool) -> void:
	# 状态机保留至视图切换时清理，避免回调悬空
	pass

func _free_combat_node() -> void:
	if combat_node != null and is_instance_valid(combat_node):
		combat_node.queue_free()
	combat_node = null
	combat_view.combat_node = null

# ------------------------------------------------------------
# 区域视觉
# ------------------------------------------------------------
func _set_region_visuals(region: int) -> void:
	var r = clampi(region, 0, BG_NAMES.size() - 1)
	var tex = load("res://assets/backgrounds/%s_bg.png" % BG_NAMES[r])
	if tex:
		background.texture = tex
	weather.set_biome(r)

# ------------------------------------------------------------
# 屏幕震动
# ------------------------------------------------------------
func _on_shake(intensity: float, duration: float) -> void:
	_shake_amount = intensity
	var tw = create_tween()
	tw.tween_method(func(v): _shake_amount = v, intensity, 0.0, duration)

func _process(_delta: float) -> void:
	if _shake_amount > 0.05:
		shake_root.position = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
	elif shake_root.position != Vector2.ZERO:
		shake_root.position = Vector2.ZERO

# ------------------------------------------------------------
# Toast
# ------------------------------------------------------------
func _show_toast(message: String) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.07, 0.09, 0.14, 0.92), UITheme.C_GOLD, 1, 16, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl = Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	toast_layer.add_child(panel)

	panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

	# 最多同时 4 条
	if toast_layer.get_child_count() > 4:
		toast_layer.get_child(0).queue_free()

# ------------------------------------------------------------
# 快捷键
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if cg_layer != null and cg_layer.is_playing():
		return   # CG 播放期间屏蔽全局快捷键（CG 层自行处理空格/回车）
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if modal_layer.is_open():
					modal_layer.try_escape()
			KEY_B:
				# 弹窗打开时也可叠加查看背包（栈式弹窗，关闭后恢复原窗口）
				if _current_view in ["map", "combat"]:
					SignalBus.show_modal.emit("bag", {})
			KEY_C:
				SignalBus.show_modal.emit("codex", { "tab": "equip" })
			KEY_V:
				if _current_view in ["map", "combat"]:
					SignalBus.show_modal.emit("stats", {})
			KEY_1, KEY_KP_1:
				_combat_key(1)
			KEY_2, KEY_KP_2:
				_combat_key(2)
			KEY_3, KEY_KP_3:
				_combat_key(3)
			KEY_4, KEY_KP_4:
				_combat_key(4)
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, \
			KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, \
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_map_key(event.keycode)

func _combat_key(idx: int) -> void:
	if _current_view == "combat" and not modal_layer.is_open():
		combat_view.handle_key(idx)

func _map_key(keycode: int) -> void:
	if _current_view == "map" and not modal_layer.is_open():
		map_view.handle_key(keycode)
