extends Node

# 全局信号总线 - 所有模块通过此通信

# 战斗相关
signal combat_started(enemies: Array)
signal combat_ended(victory: bool)
signal player_turn_started
signal enemy_turn_started
signal turn_ended(turn_number: int)
signal player_attacked(target: int, damage: int, is_crit: bool)
signal player_used_skill
signal player_defended(shield_amount: int)
signal player_used_potion(heal_amount: int)
signal enemy_acted(enemy_index: int, action: String)
signal damage_taken(target: String, amount: int)
signal shield_changed(new_shield: int)
signal hp_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal enemy_hp_changed(enemy_index: int, current: int, maximum: int)
signal enemy_shield_changed(enemy_index: int, amount: int)
signal skill_cooldown_changed(turns: int)
signal cooldowns_changed
signal combat_log_message(text: String, message_type: String)
signal enemy_defeated(enemy_index: int)
signal elem_proc_triggered(target_idx: int, proc_name: String)
signal bow_combo_changed(combo: int)
signal boss_phase_changed(phase: int)
signal floating_text_spawned(text: String, position: Vector2, color: Color)
signal shake_screen(intensity: float, duration: float)

# 地图相关
signal map_generated
signal node_entered(node_type: String)
signal region_changed(region_index: int)
signal region_cleared(region_index: int)
signal game_victory
signal game_defeat

# 装备相关
signal equipment_changed(slot: String, item: Dictionary)
signal bag_changed(items: Array)
signal item_upgraded(item: Dictionary)
signal drop_received(item: Dictionary)
signal gold_changed(amount: int)
signal potion_changed(count: int)

# 剧情 CG
signal play_cg(ids: Array, tag: String)
signal cg_finished(tag: String)

# UI相关
signal show_modal(modal_type: String, data: Dictionary)
signal hide_modal
signal show_toast(message: String)
signal view_changed(view_name: String)
signal state_changed(new_state: String)
