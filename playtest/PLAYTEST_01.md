# Playtest 01 — partida completa (2026-11-08)

Como foi: `tools/playtest_match.gd` jogou 600 s de partida (6 civs; a civ 1 = "você", controlada por um bot agressivo de verdade, 5 bots rivais), do início à tela de resultados. Log completo em `.playtest_full.log`. Saída 0, sem erro de script nem aviso do Godot.

## Resultado
| Civ | Final | Pico |
|---|---|---|
| 2 (1º) | 18,7% | 21,4% |
| 3 | 18,4% | **25,0%** |
| **1 (você)** | **17,8%** | 18,7% |
| 6 | 16,1% | 19,4% |
| 4 | 16,1% | 17,9% |
| 5 | 12,8% | 15,6% |

Não foi possível "dominar o máximo do planeta": ninguém passou de 25%, e o 1º lugar venceu o 3º por 0,9 ponto.

## O que funcionou (testado)
Abertura (descida + contagem 5..1) · 449 circuitos fechados · 44 conversões de território rival · 36 cortes de rastro · território amputado (DD-102) · recall sem retaguarda (DD-123, 1x) · 5 tipos de bônus (69 coletas) · os 7 eventos globais (meteoro com cratera) · TIME_UP → TALLY → REPLAY → RESULTS · painel de resultados com XP/moedas/nível/3 conquistas · memória estável (295→301 MB), 0 nós órfãos.

## Bugs confirmados
1. **Encostar no próprio rastro não fecha área** (18 amostras, todas as civs). Só fecha ao voltar ao território. (Pedido do Diretor, ainda não implementado.)
2. **Circuito "vazio": ~10% dos circuitos (44 de 449) fecham com menos de 8 células** — cerca sem área. Provável: rastro curto que sai e volta na própria borda. Hoje conta como "Área conquistada" nas estatísticas (você: 66).
3. **Corte perdido (2x):** civ encostou (<1,0) no rastro de outra e não cortou em 1 s. Investigar: limite de `min_points_to_cut` (5)? rastro com escudo? raio 1,5 pequeno?
4. **Picos de quadro:** 694 ms no "GO!" (t=7 s, entrada em jogo) e 408 ms na abertura (t=5 s); 100–260 ms a cada conversão grande; 317 quadros > 60 ms em 625 s. Média **sobe de 6 ms (início) para 11–18 ms (meio/fim)** — e isto é headless, SEM desenhar. No Latitude 5400 com tela vai pesar mais.
5. Menor: contagem da abertura repete o "2" (`respawn de VOCÊ em 2` aparece duas vezes, t=5,0).

## Coisas que não fazem sentido / precisam de decisão
6. **O planeta acaba cedo:** 97% livre em t=15 s → 38% em t=195 s → **0,6% em t=375 s**. Os últimos ~225 s (37% da partida) são só troca de território; todos terminam 13–19% (média matemática = 16,7%). Não existe bola de neve nem vencedor claro. Ideias: vantagem de quem cerca (fechar em volta de área rival converte mais), custo/fadiga de expansão, objetivos que mudem ao final.
7. **Eventos globais sem coordenação:** cada evento tem timer próprio (`global_event.gd` 60–110 s; meteoro 45–90 s) → em t≈70 s dispararam 4 juntos (verme, furacão, terremoto, chuva ácida), depois 3 em t≈202 e 3 em t≈331. 24 eventos em 600 s. Falta um diretor central (1 por vez ou intervalo mínimo entre eles) — confirmar com o GDMD DD-106.
8. **Nenhuma eliminação em 10 min** (kills 0, nenhuma base caiu, vida mínima 4). Queda de base, ruína e herança (DD-100/DD-122) **não aparecem numa partida natural**: só testadas por smoke. Pode ser que o jogo esteja fácil demais para sobreviver.
9. **Vida chegou a 20** (`hp20`), mas o DD-105 fixa 16 pontos. Se for o bônus VIDA EXTRA, documentar no GDMD (hoje não consta no DD-105).
10. **Dominação sem efeito de onda** e pintura fixa (300 células/quadro, ordem da cerca para o miolo, alfa quase binário). (Pedido do Diretor, ainda não implementado.)
11. Empate no ranking (civ 6 e civ 4, ambas 16,1%) sem critério de desempate visível.

## Não coberto nesta partida
Defensores/obstáculos (SYS-006/007: sem gancho no log) · eliminação e herança de ruína · multiplayer · toque/UI real em tela · áudio.

## Sugestão de ordem para corrigir
(1) toque no próprio rastro + onda de dominação [pedido anterior] → (4) picos de quadro → (2)/(3) → (7) diretor de eventos → (6) decisão de balanceamento com o Diretor.
