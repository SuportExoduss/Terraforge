# Playtest 02 — refeito após as correções (2026-11-09)

Mesma partida do PLAYTEST 01: `tools/playtest_match.gd`, 600 s, 6 civs (civ 1 = "você", bot agressivo), do início à tela de resultados. Log: `.playtest_full3.log`. Saída 0, sem erro de script. (Uma rodada anterior, `.playtest_full2_run1.log`, achou o defeito do portão de eventos descrito no item 7; esta é a rodada final, já com a correção.)

Antes do playtest: 22 smokes de regressão + 8 de eventos passaram (inclui os novos `selftouch`, `countdown`, `event_gate`).

## Resultado da partida
| Civ | Final | Pico |
|---|---|---|
| 4 (1º) | 22,8% | **29,9%** |
| 5 | 19,7% | 21,5% |
| 2 | 16,2% | 18,5% |
| 3 | 16,1% | 18,9% |
| 6 | 14,1% | 16,8% |
| 1 (você) | 11,0% — **ELIMINADA** (t=464 s, por civ 5) | 13,2% |

Painel de resultados, XP/moedas e reinício funcionaram como antes.

## Os 11 itens — antes × depois
| # | Item | PLAYTEST 01 | PLAYTEST 02 | Situação |
|---|---|---|---|---|
| 1 | Tocar o próprio rastro fecha a área | 18 amostras sem fechar | **0** | ✅ corrigido |
| 2 | Circuitos "vazios" contando como área | 44/449 contavam | 40/491 ainda acontecem, mas **não contam mais** (exige ≥ 12 células novas; "você": 59 circuitos fechados, estatística mostra só os reais) | ✅ corrigido (na estatística) |
| 3 | Corte perdido | 2 | **0** (era falso positivo do observador: toque mútuo) | ✅ |
| 4 | Picos de quadro | máx 694 ms; 317 quadros > 60 ms | máx 112 ms jogando (131 ms só no instante de montar o painel final); **35** quadros > 60 ms; p99 11–43 ms | ✅ (maior parte era o `print` do Windows) |
| 5 | Contagem repete o "2" | repetia | 5 4 3 2 1 0, sem repetir | ✅ |
| 6 | Planeta acaba cedo / sem líder | livre 0,6% em t=375; todos 13–19% | livre 0,7% em t=375 e 0% em t=465 (**igual**); mas agora há líder (pico 29,9%) e dispersão 11–23% | 🟡 melhorou, **decisão do Diretor** (ver abaixo) |
| 7 | Eventos juntos | 3–4 ao mesmo tempo; 24 eventos | **nunca juntos**: 12 eventos, menor intervalo entre avisos 30,6 s (5 s de aviso + 25 s de folga); os 7 tipos apareceram | ✅ (ver defeito achado) |
| 8 | Nenhuma eliminação | 0 | **1 natural** (civ 1, t=464 s); a rodada anterior teve 2 | ✅ (a queda de base/ruína continua coberta pelos smokes dedicados; o log do playtest não tem gancho para elas) |
| 9 | Vida 20 vs DD-105 (16) | estranhado | 20 = VIDA EXTRA (+4, teto 20); documentado no DD-129 | ✅ documentado |
| 10 | Dominação sem onda | sem efeito | onda 0,35–1,2 s (DD-127); no headless só dá para ver que a pintura termina sem fila (`pintura pendente 0`) — **o visual precisa do seu olho** | ✅ implementado / 👁 conferir |
| 11 | Desempate do ranking | sem critério | critério no `MatchStats` (áreas, depois cortes, depois id), testado no smoke; esta partida não teve empate | ✅ |

## Defeito achado pelo próprio PLAYTEST 02 (e já corrigido)
Na 1ª rodada o portão do DD-128 favorecia quem vem primeiro na árvore de nós: de 13 eventos, 11 foram meteoro/tsunami/vulcão e **terremoto e chuva ácida nunca rodaram**. Agora o evento que acha o portão fechado volta a tentar depois de 0–8 s sorteados. Resultado na rodada final: furacão 2, meteoro 2, tsunami 2, verme 2, chuva ácida 2, terremoto 1, vulcão 1. O smoke `event_gate` agora exige ≥ 4 tipos diferentes (antes ≥ 3 por causa do mesmo defeito).

## O que continua sem solução (precisa de você)
**Item 6 — o planeta enche por volta de t=375–465 s.** Os últimos ~35% da partida são só troca de território. As ambições dos bots (DD-130) criaram um líder (pico 29,9%) e eliminações, mas não mudam o fato de o mapa lotar. Opções, da mais barata à mais cara:
1. Aceitar: com humanos no lugar dos bots o ritmo é outro; testar com gente antes de mexer.
2. Partida mais curta (ex.: 8 min) ou planeta maior.
3. Mecânica de fim de jogo (conversão mais forte para quem cerca área rival, ou um evento "grande" nos últimos 2 min).

## Ainda não coberto
Defensores/obstáculos no log do playtest · queda de base e herança de ruína em partida natural · multiplayer · toque/UI em tela real · áudio · o visual da onda de dominação e do meteoro (smokes cobrem a geometria; falta o olho humano).
