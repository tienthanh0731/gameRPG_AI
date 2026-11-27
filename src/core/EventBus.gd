extends Node

# Global EventBus for loose coupling across all game systems

# Talent & Character
signal talent_awakened(talent_data: Dictionary)
signal character_created(char_data: Dictionary)
signal player_died(day_survived: int, sp_earned: int, record_broken: bool)

# Time & Survival Cycle
signal time_updated(hour: int, minute: int)
signal phase_changed(phase_name: String)
signal day_started(day_num: int)
signal dusk_warning(wave_size: int, monster_type: String)
signal night_started(wave_size: int)
signal raid_wave_cleared(day_num: int)
signal day_ended(day_num: int, sp_today: int, rank_tier: String, chest_reward: Dictionary)
signal day_summary_ready(summary: Dictionary)
signal talent_changed(talent_data: Dictionary)

# Score & Points
signal sp_added(amount: int, reason: String)
signal score_updated(today_sp: int, total_season_sp: int)

# Dungeon
signal dungeon_entered(dungeon_name: String)
signal dungeon_cleared(dungeon_name: String, reward_data: Dictionary)
signal dungeon_exited()

# Building & Base
signal structure_placed(struct_type: int, pos: Vector2)
signal structure_damaged(struct_id: int, current_hp: int, max_hp: int)
signal structure_destroyed(pos: Vector2)

# Combat
signal enemy_killed(enemy_type: String, is_elite: bool, pos: Vector2)
