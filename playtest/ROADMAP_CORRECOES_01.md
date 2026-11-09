# Roadmap de correções — a partir do PLAYTEST_01 (2026-11-08)

Regra: nenhum sinal do EventBus muda de assinatura (multiplayer, replay e recuperação dependem deles). Cada item tem UM teste que falha se a lógica quebrar.

| # | Item | Causa | Correção | Onde | Teste |
|---|---|---|---|---|---|
| 1 | Encostar no próprio rastro não fecha | `RunnerTrail` só fecha ao voltar ao território (`inside and not _was_inside`) | A cada 0,05 s mede a distância do corredor aos SEGMENTOS do próprio rastro (ignora os últimos pontos); encostou → circuito = anel (do ponto tocado até agora), fecha, limpa, e fica 0,5 s sem gravar até a posse chegar | `runner_trail.gd` | `smoke_trail` (fase nova: laço que cruza o próprio rastro anexa área) |
| 2 | Circuito "vazio" conta como área | `loops` conta todo `territory_loop_closed`, mesmo com 6 células | Sinal NOVO `territory_loop_claimed(owner, células)` emitido pelo mapa ao publicar; `MatchStats` conta `loops` só com ≥ 12 células novas | `event_bus.gd`, `territory_map.gd`, `match_stats.gd` | `smoke_stats` (vazio não conta, cheio conta) |
| 3 | Corte perdido (2x) | **Falso positivo do observador**: o playtest media o cruzamento de rastros só em um sentido; o toque mútuo já cortava | Ferramenta corrigida (`_cross_mutual`, `_cut_near`); o jogo não mudou | `tools/playtest_match.gd` | PLAYTEST_02 (BUG? = 0) |
| 4 | Picos de quadro (694 ms no GO; 100–260 ms por conquista) | **Artefato de medição**: `print()` no `godot_console` do Windows custa 10–30 ms por linha; o custo real da conquista é pequeno | Playtest agora roda `--headless --quiet` e grava num arquivo; pintura em onda com orçamento (item 10) | `tools/playtest_match.gd`, `territory_painter.gd` | PLAYTEST_02: p99 e máximo |
| 5 | Contagem da abertura repete o "2" | Emissão dupla no respawn_countdown | Emitir só quando o inteiro muda | abertura (`home_territory`/`match_flow`) | `smoke_flow` |
| 6 | Planeta acaba em 375 s; todos 13–19% | 6 bots idênticos → média matemática 16,7% | **DD-130**: cada bot tem "ambição" 0,6–1,6 (saída, exposição, caça) | `bot_steering.gd` | PLAYTEST_02: 1º lugar > 25% |
| 7 | Eventos globais disparam juntos | Cada evento tem timer próprio | **DD-128**: portão estático em `GlobalEvent` (1 por vez, folga 25 s), usado também pelo meteoro | `global_event.gd`, `meteor_event_system.gd` | `smoke_event_gate` |
| 8 | Nenhuma eliminação em 10 min | Por projeto (16 pts, dano 2, regenera) a eliminação natural é rara | Mais caça (DD-130); DD-100/102/122/123 seguem cobertos por smokes; PLAYTEST conta as ocorrências sem forçar | `bot_steering.gd` | PLAYTEST_02 |
| 9 | Vida chegou a 20 (DD-105 = 16) | VIDA EXTRA (+4, teto 20) não estava no GDMD | **DD-129** documenta | `07_ADENDOS` (Adendo 07) | — |
| 10 | Dominação sem onda nem "subida" | Ordem de células por índice, alfa binário | Ordem em ONDA (BFS a partir do território já seu); pintura no ritmo do tempo (0,35–1,2 s); alfa em 3 degraus (sobe do chão) | `territory_map.gd`, `territory_painter.gd` | `smoke_territory` (onda perto→longe) + `smoke_replay` (estado final idêntico) |
| 11 | Empate no ranking sem critério | `sort` só por domínio | Desempate: mais área conquistada (`loops`), depois mais cortes, depois menor id | `match_stats.gd` | `smoke_stats` |

Ordem: 1 → 10 → 2 → 3 → 4 → 5 → 11 → 7 → 6 → 8 → 9 → reteste completo (PLAYTEST_02).

Numeração final: DD-127 (toque/onda/área conquistada/desempate/contagem), DD-128 (portão dos eventos), DD-129 (VIDA EXTRA), DD-130 (ambição dos bots) — Adendo 07.
