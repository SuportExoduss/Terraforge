# Roadmap — Passos 97 a 101 (pedido "mais 5 passos", 2026-11-14)

Vêm dos CRITÉRIOS DE TESTE do GDMD que ainda não tinham teste: SYS-001 (Conquista Territorial, cap. 03 parte 04: "funcionamento próximo aos polos",
"fechamento de áreas pequenas e grandes", "ausência de perdas por erro de cálculo", "não fechar com rastro de terceiros") e SYS-007 (Obstáculos, parte 10:
"nunca bloquear completamente uma rota", "eventos modificam obstáculos temporariamente").
Regra: 1 commit local por passo (nunca `push`), smoke novo + regressão do trecho verde antes de cada commit; nenhum sinal do EventBus muda.
O trabalho de arte do André não entra nos commits.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 97 | Laços nos polos | SYS-001 teste "próximo aos polos" | `smoke_polar_loops`: o mesmo laço nos dois polos e no equador conquista a mesma área; corrige o que quebrar |
| 98 | Áreas pequenas e grandes | SYS-001 "pequenas/grandes" + "sem perdas por erro de cálculo" | `smoke_loop_sizes`: laços de 4° a 100°, o miolo é do jogador e a contagem de células bate com o mapa |
| 99 | Rastro de terceiros | SYS-001 regra "não fechar área com trilha alheia" | `smoke_third_trail`: cruzar o rastro do rival não fecha nem conquista nada |
| 100 | Nunca bloquear a rota | SYS-007 regra 1 | `smoke_obstacle_routes`: os obstáculos nunca formam um anel fechado; sempre há passagem |
| 101 | Eventos mexem nos obstáculos | SYS-007 "interação com eventos" | Tsunami e Vulcão liberam obstáculos por alguns segundos (como o meteoro) e eles voltam depois |

Status:
- Passo 97 ✔ (`smoke_polar_loops`: o mesmo laço de 12° fechado no polo sul e em quatro pontos do equador conquista 291–293 células (±0,4%), o centro vira do jogador e o lado oposto do planeta não é tocado; laços de 30° nos DOIS polos (o norte engloba a base) não deixam buracos e as calotas ficam idênticas (1 171 células). Nada precisou de correção: a grade é de baldes 3D, sem latitude/longitude, e os pontos de rotação do corredor já tinham saída para os polos; a base fica no polo norte, por isso o laço pequeno de lá é pulado)
- Passo 98 ✔ (`smoke_loop_sizes`: laços de 4°, 25°, 45°, 70°, 90° e 100° de raio (52 a 10 303 células conquistadas, 67–93 ms cada, síncrono) fecham sempre a MENOR das duas bandas do círculo (o de 100° é, visto do outro lado, um de 80°): sem buracos dentro, nada conquistado fora, nenhuma célula do jogador perdida, nenhum dono estranho e o placar `_counts` igual à contagem real do mapa. Círculo máximo (90°) conquista meio planeta, sem absurdo. Nada precisou de correção)
- Passo 99 ✔ (`smoke_third_trail`: com um rastro de rival falso no `Services.trails`, tocar nele NÃO fecha circuito (o anel só usa os pontos do PRÓPRIO rastro), o sensor de corte corta o rival (DD-099) e quem encostou fica com o rastro e o território exatamente como estavam. Nada precisou de correção: a regra do GDMD já vale por construção (`RunnerTrail._close_on_self_touch` varre só `points` próprios))
