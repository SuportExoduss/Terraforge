extends Node
## Correio central do jogo (autoload). Módulos NUNCA se referenciam: só emitem/ouvem aqui.
## Espelha os eventos do Core do Unity (ids de civilização são int 0..255).

signal base_fallen(owner_id: int, conqueror_id: int)
signal base_relocated(owner_id: int, new_position: Vector3)
signal bonus_activated(owner_id: int, kind: String, seconds: float)   # seconds = 0 -> efeito instantâneo
signal bonus_drop_requested(center: Vector3, count: int)
signal civilization_eliminated(owner_id: int)
signal civilization_killed(victim_id: int, killer_id: int)   # eliminada POR CORTE de rastro (eventos/defensores não creditam)
signal global_event_active_changed(active: bool)   # um evento global (chuva/verme/terremoto) entrou ou saiu da execução
signal global_event_warning(event_name: String, seconds_remaining: int)
signal health_changed(owner_id: int, points: int, max_points: int)
signal match_state_changed(state: int)   # MatchFlow.State: a máquina de estados da partida avançou
signal match_clock_changed(seconds_remaining: int)
signal match_started
signal match_ended
signal minimap_dragged(delta_pixels: Vector2)
signal minimap_held(is_held: bool)
signal radial_damage(center: Vector3, inner_radius: float, inner_damage: int, inner_returns_to_base: bool, mid_radius: float, mid_damage: int, outer_radius: float, outer_damage: int)
signal respawn_countdown(owner_id: int, seconds_remaining: int)
signal territory_cells_claimed(owner_id: int, cell_positions: PackedVector3Array, cell_spacing: float)
signal territory_cells_converted(conqueror_id: int, planet_fraction: float)   # parte do planeta tomada de OUTRAS civilizações
signal territory_loop_closed(owner_id: int, trail_points: PackedVector3Array)
signal territory_loop_claimed(owner_id: int, new_cells: int)   # circuito já resolvido pelo mapa: quantas células mudaram de dono (poucas = circuito "vazio")
signal territory_score_changed(owner_id: int, owned_fraction: float)
signal trail_anchor_lost(owner_id: int)
signal trail_cut(victim_id: int, attacker_id: int)
