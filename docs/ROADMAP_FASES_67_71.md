# Roadmap — Passos 67 a 71 (pedido "continue mais 5 passos", 2026-11-10)

Todos vêm do GDMD Cap.03 P11 (Encerramento da Partida), que ainda tinha lacunas: o replay deve mostrar "grandes eventos"
(o código só repintava território) e o planeta final deve deixar "observar cada civilização" e "analisar estratégias".
Regra: 1 commit por passo, smoke novo + regressão do trecho verde antes de cada commit; nenhum sinal do EventBus muda de assinatura.
Os `.import` modificados em art/ são do trabalho de arte do André: não entram nos commits.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 67 | Relógio no replay | Cap.03 P11 REPLAY | legenda "REPLAY m:ss" no alto da tela durante o replay, com o tempo da partida que está sendo mostrado |
| 68 | Grandes eventos no replay | Cap.03 P11 REPLAY "grandes eventos" | o replay anota cada evento global (nome + instante) e mostra o nome na legenda quando o replay chega nele |
| 69 | Pular o replay | DD-038, Cap.05 P06 | clique/toque, ESPAÇO, ENTER ou ESC durante o replay vai direto para os resultados |
| 70 | Legenda da civilização observada | Cap.03 P11 "observar cada civilização / analisar estratégias" | ao apertar TAB na contemplação, uma legenda mostra nome, % do planeta e estatísticas da civilização |
| 71 | Foco em JOGAR DE NOVO | DD-038 "vontade imediata de jogar novamente" | ao abrir os resultados o botão JOGAR DE NOVO já vem com foco: ENTER joga outra partida |

Status:
- Passo 67 ✔ (relógio no replay: `MatchReplay._show_caption` cria a legenda "REPLAY m:ss" com o instante da partida mostrado e a remove em `_finish`; smoke_replay_clock)
- Passo 68 ✔ (grandes eventos no replay: `MatchReplay` anota `[relógio, nome]` no 1º aviso de cada evento (contagem que sobe = evento novo) e mostra o nome na legenda por `event_caption_seconds`; clima fica de fora (sem sinal, ponytail); smoke_replay_events)
- Passo 69 ✔ (pular o replay: `MatchFlow.skip_replay()` zera a espera só no REPLAY; `MatchReplay._unhandled_input` chama com clique, toque, ESPAÇO, ENTER ou ESC (tecla comum e eco não pulam); smoke_replay_skip)
- Passo 70 ✔ (legenda da civilização observada: `ContemplationCamera._show_caption` no TAB mostra "VOCÊ/CIVILIZAÇÃO n — x% do planeta (nº)" e áreas/tomado/cortes/eliminações, ou "(ELIMINADA)" com o auge; arrastar esconde; fonte segue `Settings.text_scale()`; smoke_contemplation_caption)
