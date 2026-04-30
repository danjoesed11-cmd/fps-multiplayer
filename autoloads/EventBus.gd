extends Node

# Economy
signal coins_changed(peer_id: int, new_total: int)
signal purchase_confirmed(peer_id: int, item_id: String)
signal purchase_denied(peer_id: int, reason: String)

# Combat
signal player_damaged(victim_id: int, attacker_id: int, amount: float)
signal player_killed(victim_id: int, killer_id: int, weapon_id: String)
signal player_respawned(peer_id: int)

# Weapons
signal weapon_switched(peer_id: int, weapon_id: String)
signal weapon_upgraded(peer_id: int, weapon_id: String, level: int)
signal ammo_changed(peer_id: int, current: int, reserve: int)

# Game mode
signal match_state_changed(new_state: int)
signal score_changed(team_id: int, new_score: int)
signal flag_picked_up(peer_id: int, flag_team_id: int)
signal flag_dropped(flag_team_id: int, position: Vector3)
signal flag_captured(capturing_team: int)
signal zone_captured(zone_id: int, team_id: int)
signal zone_progress_changed(zone_id: int, team_id: int, progress: float)
signal round_ended(winner_team: int)
signal match_over(winner_team: int)

# Social
signal chat_message_received(sender_name: String, message: String, channel: String)
signal player_joined_lobby(peer_id: int)
signal player_left_lobby(peer_id: int)

# Customization
signal cosmetic_changed(peer_id: int, slot: String, item_id: String)

# UI
signal hud_show_requested()
signal hud_hide_requested()
signal shop_open_requested()
signal shop_close_requested()
signal scoreboard_toggle_requested(visible: bool)
signal kill_feed_entry(killer_name: String, victim_name: String, weapon_id: String)
